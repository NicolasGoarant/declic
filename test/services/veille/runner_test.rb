require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

class Veille::RunnerTest < ActiveSupport::TestCase
  include VeilleSupport

  # Connecteur factice : rend des items préparés, ou lève.
  class FauxConnecteur
    def initialize(nom, items: [], statut: :ok)
      @nom, @items, @statut = nom, items, statut
    end

    def call
      Veille::Connectors::Base::Resultat.new(nom: @nom, statut: @statut, items: @items, message: "essai")
    end
  end

  class FauxEnricher
    attr_reader :vus, :usage
    def initialize = (@vus = []; @usage = { "input_tokens" => 1000, "output_tokens" => 200 })
    def enrich(c)
      @vus << c
      c.update!(item_type: "opportunite", declic_category: "rencontres", commune: "Nancy", summary: "R.", enriched_at: Time.current)
    end
  end

  def runner(connecteurs, enricher: FauxEnricher.new, max: 30)
    Veille::Runner.new(connecteurs: connecteurs, enricher: enricher, redacteur: Object.new, max: max, http: Object.new,
                       ingester: Veille::RawIngester.new(today: Date.new(2026, 10, 13)))
  end

  test "collecte, stocke, puis enrichit : tout reste en attente de relecture" do
    items = 3.times.map { |i| item(title: "Événement #{i}", starts_on: Date.new(2026, 11, 1 + i)) }
    fiches_avant = Opportunity.count + Story.count
    rapport = runner([FauxConnecteur.new("Agenda", items: items)]).run

    assert_equal 3, rapport.crees
    assert_equal 3, rapport.enrichis
    assert_equal ["pending"], Veille::Candidate.distinct.pluck(:status)
    assert_equal fiches_avant, Opportunity.count + Story.count, "aucune publication automatique"
  end

  test "n'enrichit pas plus de 30 éléments par exécution et reporte le reste" do
    items = 35.times.map { |i| item(title: "Élément #{i}", starts_on: Date.new(2027, 1, 1) + i) }
    enricher = FauxEnricher.new
    rapport = runner([FauxConnecteur.new("Agenda", items: items)], enricher: enricher).run

    assert_equal 30, rapport.enrichis
    assert_equal 5, rapport.restants
    assert_equal 5, Veille::Candidate.a_enrichir.count

    # Le lendemain, les 5 restants sont traités sans rien recollecter en double.
    rapport2 = runner([FauxConnecteur.new("Agenda", items: items)]).run
    assert_equal 0, rapport2.crees
    assert_equal 35, rapport2.doublons
    assert_equal 5, rapport2.enrichis
  end

  test "respecte l'ordre de priorité des sources" do
    a = item(origin: "gazette", title: "Gazette", url: "https://exemple.fr/g")
    b = item(origin: "jeveuxaider", title: "Mission", url: "https://exemple.fr/m")
    enricher = FauxEnricher.new
    runner([FauxConnecteur.new("X", items: [a, b])], enricher: enricher, max: 1).run

    assert_equal ["Mission"], enricher.vus.map(&:title)
  end

  test "une source qui refuse ou échoue n'arrête pas les autres" do
    rapport = runner([
      FauxConnecteur.new("Refusée", statut: :refuse),
      FauxConnecteur.new("Cassée", statut: :erreur),
      FauxConnecteur.new("Bonne", items: [item(title: "Ok")])
    ]).run

    assert_equal %i[refuse erreur ok], rapport.sources.map(&:statut)
    assert_equal 1, rapport.crees
  end

  test "consigne le coût estimé dans les logs" do
    io = StringIO.new
    log = Logger.new(io)
    Veille::Runner.new(connecteurs: [FauxConnecteur.new("A", items: [item(title: "Un")])], enricher: FauxEnricher.new,
                       redacteur: Object.new, http: Object.new, logger: log,
                       ingester: Veille::RawIngester.new(today: Date.new(2026, 10, 13))).run

    # 1000 tokens d'entrée + 200 de sortie, tarif Haiku : 0,001 + 0,001 = 0,0020 USD
    assert_match(/coût estimé 0\.0020 USD/, io.string)
    assert_match(/enrichis 1/, io.string)
  end

  test "une erreur d'API sur un élément n'empêche pas les suivants" do
    enricher = FauxEnricher.new
    appels = 0
    enricher.define_singleton_method(:enrich) do |c|
      appels += 1
      raise AnthropicClient::ConnectionError, "timeout" if appels == 1
      c.update!(item_type: "opportunite", declic_category: "rencontres", commune: "Nancy", summary: "R.", enriched_at: Time.current)
    end
    rapport = runner([FauxConnecteur.new("A", items: [item(title: "Un"), item(title: "Deux")])], enricher: enricher).run

    assert_equal 1, rapport.erreurs_ia
    assert_equal 1, rapport.enrichis
  end

  test "une clé Anthropic invalide arrête l'enrichissement sans exploser" do
    enricher = FauxEnricher.new
    enricher.define_singleton_method(:enrich) { |_c| raise AnthropicClient::AuthenticationError, "401" }
    rapport = runner([FauxConnecteur.new("A", items: [item(title: "Un"), item(title: "Deux")])], enricher: enricher).run
    assert_equal 1, rapport.erreurs_ia
    assert_equal 0, rapport.enrichis
  end

  test "l'enrichissement s'arrête après 3 erreurs d'affilée (crédit épuisé, panne)" do
    enricher = FauxEnricher.new
    enricher.define_singleton_method(:enrich) { |_c| raise AnthropicClient::Error, "HTTP 400 — credit balance is too low" }
    items = 10.times.map { |i| item(title: "Élément #{i}", starts_on: Date.new(2027, 1, 1) + i) }
    rapport = runner([FauxConnecteur.new("A", items: items)], enricher: enricher).run

    assert_equal 3, rapport.erreurs_ia
    assert_equal 10, Veille::Candidate.a_enrichir.count, "tout reste à enrichir pour le lendemain"
  end

  test "l'estimation de coût suit le modèle" do
    usage = { "input_tokens" => 1_000_000, "output_tokens" => 1_000_000 }
    assert_in_delta 6.0,  Veille::Cout.estimer("claude-haiku-4-5-20251001", usage), 0.001
    assert_in_delta 18.0, Veille::Cout.estimer("claude-sonnet-5", usage), 0.001
    assert_equal 0.0, Veille::Cout.estimer("claude-haiku-4-5", nil)
  end

  # --- Étape « rédiger » ---------------------------------------------------

  RECIT_OK = "Elle a rouvert la porte d'un ancien atelier de couture, au cœur du quartier. Depuis, des voisins y apprennent " \
             "les gestes de la réparation. Autour de la machine à coudre, les conversations se nouent."

  def histoire_enrichie(**attrs)
    candidat(**{ origin: "presse", item_type: "belle_histoire", commune: "Laxou", summary: "Une couturière rouvre un atelier à Laxou.",
               enriched_at: Time.current, full_text: nil }.merge(attrs))
  end

  # Rend, dans l'ordre, les réponses (texte JSON ou exception) ; la dernière se répète.
  def redacteur(*reponses, usage: { "input_tokens" => 100, "output_tokens" => 100 })
    textes = reponses.dup
    client = FakeAnthropicClient.new(usage: usage)
    client.define_singleton_method(:messages) do |**kw|
      @calls << kw
      r = textes.size > 1 ? textes.shift : textes.first
      raise r if r.is_a?(Exception)

      { "content" => [{ "type" => "text", "text" => r }], "usage" => usage }
    end
    Veille::Redaction::Brouillon.new(client: client)
  end

  def recit(brouillon = RECIT_OK) = { brouillon: brouillon, personne: "Nadia", champs_manquants: [] }.to_json

  def lancer_rediger(red, **opts)
    Veille::Runner.new(connecteurs: [], enricher: FauxEnricher.new, redacteur: red, **opts).run
  end

  test "rédige le récit des belles histoires enrichies, sans rien publier" do
    c = histoire_enrichie
    opportunite = candidat(item_type: "opportunite", summary: "R.", enriched_at: Time.current)
    fiches = Opportunity.count + Story.count
    rapport = lancer_rediger(redacteur(recit))

    assert_equal 1, rapport.rediges
    assert_equal "redige", c.reload.draft_status
    assert_includes c.draft_body, "Accord de la personne : à obtenir"
    assert_equal "aucun", opportunite.reload.draft_status, "les opportunités n'ont pas de récit"
    assert_equal fiches, Opportunity.count + Story.count
    assert_equal "pending", c.status
  end

  test "un récit en échec d'API repart à l'exécution suivante, sans refaire l'enrichissement" do
    c = histoire_enrichie
    r1 = lancer_rediger(redacteur(AnthropicClient::ConnectionError.new("coupé")))
    assert_equal [0, 1], [r1.rediges, r1.erreurs_redaction]
    assert_equal ["a_reprendre", 1], [c.reload.draft_status, c.draft_attempts]
    assert_equal 0, Veille::Candidate.a_enrichir.count, "l'enrichissement est acquis"

    r2 = lancer_rediger(redacteur(recit))
    assert_equal 1, r2.rediges
    assert_equal ["redige", 2], [c.reload.draft_status, c.draft_attempts]
  end

  test "3 tentatives au plus par candidat" do
    c = histoire_enrichie(draft_status: "a_reprendre", draft_attempts: 3)
    rapport = lancer_rediger(redacteur(recit))
    assert_equal 0, rapport.rediges
    assert_nil c.reload.draft_body
  end

  test "arrêt après 3 erreurs d'affilée" do
    5.times { |i| histoire_enrichie(title: "H#{i}") }
    rapport = lancer_rediger(redacteur(AnthropicClient::ConnectionError.new("coupé")))

    assert_equal 3, rapport.erreurs_redaction
    assert_equal 3, Veille::AppelIa.where(statut: "erreur_api").count, "les deux autres n'ont pas été tentés"
  end

  test "une réussite remet à zéro le compte des erreurs d'affilée" do
    4.times { |i| histoire_enrichie(title: "H#{i}") }
    e = AnthropicClient::ConnectionError.new("coupé")
    rapport = lancer_rediger(redacteur(e, e, recit, e))
    assert_equal [1, 3], [rapport.rediges, rapport.erreurs_redaction]
  end

  test "une clé invalide arrête la rédaction après la première erreur" do
    3.times { |i| histoire_enrichie(title: "H#{i}") }
    rapport = lancer_rediger(redacteur(AnthropicClient::AuthenticationError.new("401")))
    assert_equal 1, rapport.erreurs_redaction
  end

  test "un brouillon refusé par les contrôles n'est pas relancé tout seul" do
    c = histoire_enrichie
    rapport = lancer_rediger(redacteur(recit("Venez à 20h30 à l'atelier.")))
    assert_equal [1, 1], [rapport.rediges, rapport.redaction_bloquee]
    assert_equal "a_verifier", c.reload.draft_status

    assert_equal 0, lancer_rediger(redacteur(recit)).rediges
  end

  test "le plafond mensuel arrête la rédaction et laisse les récits en file" do
    Veille::AppelIa.create!(passe: "redaction", modele: "m", statut: "ok", cout_usd: 99)
    c = histoire_enrichie
    rapport = lancer_rediger(redacteur(recit))
    assert rapport.plafond
    assert_equal 0, rapport.rediges
    assert_equal "aucun", c.reload.draft_status
    assert_includes Veille::Candidate.a_rediger, c
  end

  test "ne rédige pas ce qui est écarté, sans résumé, ou déjà rédigé" do
    histoire_enrichie(discard_reason: "Hors Grand Nancy ou commune introuvable", status: "ecarte")
    histoire_enrichie(summary: nil)
    histoire_enrichie(draft_body: "Déjà là.", draft_status: "redige")
    assert_equal 0, lancer_rediger(redacteur(recit)).rediges
  end

  test "plafonne la rédaction à 30 récits par exécution et reporte le reste" do
    32.times { |i| histoire_enrichie(title: "H#{i}") }
    rapport = lancer_rediger(redacteur(recit))
    assert_equal [30, 2], [rapport.rediges, rapport.a_rediger_restants]
  end

  test "le coût de la rédaction entre dans le bilan" do
    histoire_enrichie
    io = StringIO.new
    lancer_rediger(redacteur(recit, usage: { "input_tokens" => 1_000_000, "output_tokens" => 0 }), logger: Logger.new(io))
    assert_match(/récits rédigés 1/, io.string)
    assert_match(/coût estimé 3\.0000 USD/, io.string)
  end
end
