require "test_helper"
require_relative "support"

# Fiabilisation du tri (14/11) : filtre des dates passées avant IA, seuil « à vérifier », réponse tronquée,
# regroupement des fiches de catalogue.
class Veille::FiabilisationTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 11, 14)
  USAGE = { "input_tokens" => 1_000, "output_tokens" => 100 }.freeze

  # Une réponse par appel : Hash (JSON), ou { texte:, stop_reason: } pour une réponse brute.
  class ClientEnSerie
    attr_reader :calls
    def initialize(*reponses) = (@reponses = reponses; @calls = [])
    def messages(**kw)
      @calls << kw
      r = @reponses.shift
      return { "content" => [{ "type" => "text", "text" => r.to_json }], "usage" => USAGE } unless r.key?(:texte)

      { "content" => [{ "type" => "text", "text" => r[:texte] }], "usage" => USAGE, "stop_reason" => r[:stop_reason] }
    end
  end

  def enrichir(c, *reponses)
    client = ClientEnSerie.new(*reponses)
    Veille::AiEnricher.new(client: client).enrich(c, today: TODAY)
    [c.reload, client]
  end

  def avec_env(h)
    avant = h.keys.to_h { |k| [k, ENV[k]] }
    h.each { |k, v| ENV[k] = v }
    yield
  ensure
    avant.each { |k, v| ENV[k] = v }
  end

  def faux_enricher
    Class.new do
      attr_reader :vus
      def initialize = @vus = []
      def enrich(c) = (@vus << c.id; c.update!(item_type: "opportunite", enriched_at: Time.current))
    end.new
  end

  def runner(enricher)
    Veille::Runner.new(connecteurs: [], enricher: enricher, redacteur: Object.new, today: TODAY, logger: Logger.new(nil))
  end

  # --- Étape 1 : événements passés avant l'IA -------------------------------------------------------------

  test "un événement passé est écarté avant tout appel IA ; sans date, il suit le circuit normal" do
    passe  = candidat(title: "Passé", starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 2))
    futur  = candidat(title: "Futur", starts_on: Date.new(2026, 12, 1))
    sans   = candidat(title: "Sans date")
    en_cours = candidat(title: "En cours", starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 30))
    enricher = faux_enricher

    rapport = runner(enricher).trier

    assert_equal [futur.id, sans.id, en_cours.id].sort, enricher.vus.sort
    assert_equal "ecarte", passe.reload.status
    assert_equal "Événement passé (filtre avant IA)", passe.discard_reason
    assert_nil passe.enriched_at
    assert_equal 1, rapport.avant_ia_passes
    assert_equal 0, Veille::AppelIa.count, "aucun appel facturé pour le passé"
  end

  test "la date de début sert à défaut de date de fin, et un classement manuel n'est jamais écarté" do
    debut = candidat(title: "Début seul", starts_on: Date.new(2026, 11, 13))
    main  = candidat(title: "Main", starts_on: Date.new(2026, 11, 13), classement_manuel: true)
    enricher = faux_enricher
    runner(enricher).trier
    assert_equal "ecarte", debut.reload.status
    assert_includes enricher.vus, main.id
  end

  test "le journal garde une trace de chaque écart avant IA" do
    candidat(title: "Passé", starts_on: Date.new(2026, 1, 1))
    io = StringIO.new
    Veille::Runner.new(connecteurs: [], enricher: faux_enricher, redacteur: Object.new, today: TODAY, logger: Logger.new(io)).trier
    assert_match(/écarté avant IA #\d+ \(agenda_nancy\) : Événement passé \(filtre avant IA\)/, io.string)
  end

  # --- Étape 2 : seuil « à vérifier » ---------------------------------------------------------------------

  test "un proposé sous le seuil (50 par défaut) passe à vérifier avec « Score faible (N) »" do
    c, = enrichir(candidat, reponse_ia(confiance: 35))
    assert_equal "a_verifier", c.status
    assert_match(/\AScore faible \(35\)/, c.reason)
  end

  test "à 50 et au-dessus, le proposé reste proposé ; le seuil se règle par VEILLE_SEUIL_VERIF" do
    c, = enrichir(candidat, reponse_ia(confiance: 75))
    assert_equal "pending", c.status
    avec_env("VEILLE_SEUIL_VERIF" => "80") do
      c2, = enrichir(candidat, reponse_ia(confiance: 75))
      assert_equal "a_verifier", c2.status
    end
  end

  test "un écarté reste écarté, un classé à la main reste proposé" do
    e, = enrichir(candidat, reponse_ia(confiance: 20, hors_ligne: true))
    assert_equal "ecarte", e.status
    m, = enrichir(candidat(item_type: "opportunite", declic_category: "pratiquer", classement_manuel: true), reponse_ia(confiance: 20))
    assert_equal "pending", m.status
  end

  test "Haiku et Sonnet divergents : à vérifier même avec un bon score" do
    c, = enrichir(candidat, reponse_ia(confiance: 55, famille: "decouvrir"), reponse_ia(confiance: 90, famille: "pratiquer"))
    assert_equal "a_verifier", c.status
    assert_match(/\AHaiku et Sonnet divergent/, c.reason)
  end

  test "Haiku et Sonnet d'accord : l'avis de Sonnet décide seul du seuil" do
    c, = enrichir(candidat, reponse_ia(confiance: 55, famille: "decouvrir"), reponse_ia(confiance: 90, famille: "decouvrir"))
    assert_equal "pending", c.status
  end

  # --- Étape 3 : réponse tronquée -------------------------------------------------------------------------

  test "réponse coupée par max_tokens : une nouvelle tentative, même modèle, limite doublée, tracée au journal" do
    coupee = { texte: '{"type":"opportunite","resume":"Une phrase', stop_reason: "max_tokens" }
    c, client = enrichir(candidat, coupee, reponse_ia(confiance: 80))

    assert_equal 2, client.calls.size
    assert_equal client.calls[0][:model], client.calls[1][:model]
    assert_equal client.calls[0][:max_tokens] * 2, client.calls[1][:max_tokens]
    assert_equal "pending", c.status
    assert_equal %w[illisible ok], c.appels_ia.order(:id).pluck(:statut)
    assert_match(/tronquée à 4000 jetons/, c.appels_ia.order(:id).first.erreur)
  end

  test "une réponse illisible qui n'est pas tronquée n'est pas retentée" do
    c = candidat
    client = ClientEnSerie.new({ texte: "pas du json", stop_reason: "end_turn" })
    assert_raises(Veille::AiPass::ParseError) { Veille::AiEnricher.new(client: client).enrich(c, today: TODAY) }
    assert_equal 1, client.calls.size
  end

  test "second avis illisible : le premier avis est gardé et le candidat passe à vérifier" do
    sans_json = { texte: "pas du json", stop_reason: "end_turn" }
    c, = enrichir(candidat, reponse_ia(confiance: 55), sans_json)
    assert_equal "a_verifier", c.status
    assert_match(/\ASecond avis illisible/, c.reason)
    assert_equal 55, c.score
  end

  # --- Étape 5 : catalogue de formation -------------------------------------------------------------------

  test "le texte du menu n'est pas envoyé à l'IA pour une formation" do
    texte = "Aller au contenu Se pré inscrire Nos centres breadcrumb Accueil Titre pro Soudeur Public et prérequis Aucun"
    c = candidat(origin: "formation", full_text: texte)
    _, client = enrichir(c, reponse_ia)
    contenu = client.calls.first[:messages].first[:content]
    assert_includes contenu, "Titre pro Soudeur"
    assert_not_includes contenu, "Se pré inscrire"
  end

  test "les quasi-doublons d'une formation sont écartés « Doublon de #id » sans appel IA" do
    src = Veille::Source.create!(name: "Pôle formation UIMM Lorraine", kind: "presse", url: "https://exemple.fr")
    titre = "Formation préparatoire à l'habilitation électrique"
    a = candidat(origin: "formation", source: src, title: "#{titre} Personnel non électricien B0 Initial")
    b = candidat(origin: "formation", source: src, title: "#{titre} - Personnel non électricien BS - Recyclage")
    d = candidat(origin: "formation", source: src, title: "#{titre} - Personnel électricien BT HTA - Initiale")
    autre = candidat(origin: "formation", source: src, title: "Titre pro Soudeur assembleur industriel (SAI)")
    enricher = faux_enricher

    rapport = runner(enricher).trier

    assert_equal [a.id, autre.id].sort, enricher.vus.sort
    [b, d].each do |x|
      assert_equal "ecarte", x.reload.status
      assert_equal "Doublon de ##{a.id}", x.discard_reason
    end
    assert_equal 2, rapport.avant_ia_doublons
  end

  test "deux sessions de dates différentes ne sont pas des doublons" do
    src = Veille::Source.create!(name: "Organisme", kind: "presse", url: "https://exemple.fr")
    a = candidat(origin: "formation", source: src, title: "Excel", starts_on: Date.new(2027, 1, 10))
    b = candidat(origin: "formation", source: src, title: "Excel", starts_on: Date.new(2027, 2, 10))
    enricher = faux_enricher
    runner(enricher).trier
    assert_equal [a.id, b.id].sort, enricher.vus.sort
  end
end
