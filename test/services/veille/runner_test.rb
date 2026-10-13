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
    Veille::Runner.new(connecteurs: connecteurs, enricher: enricher, drafter: Object.new, max: max, http: Object.new,
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
                       drafter: Object.new, http: Object.new, logger: log,
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
end
