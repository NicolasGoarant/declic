require "test_helper"
require_relative "support"

class Veille::AiEnricherEscaladeTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)
  USAGE = { "input_tokens" => 1_000, "output_tokens" => 100 }.freeze

  # Rend une réponse par appel, dans l'ordre, et retient les paramètres reçus.
  class ClientEnSerie
    attr_reader :calls
    def initialize(*reponses) = (@reponses = reponses; @calls = [])
    def messages(**kw)
      @calls << kw
      { "content" => [{ "type" => "text", "text" => @reponses.shift.to_json }], "usage" => USAGE }
    end
  end

  def avec_env(h)
    avant = h.keys.to_h { |k| [k, ENV[k]] }
    h.each { |k, v| ENV[k] = v }
    yield
  ensure
    avant.each { |k, v| ENV[k] = v }
  end

  def enrichir(c, *reponses)
    client = ClientEnSerie.new(*reponses)
    Veille::AiEnricher.new(client: client).enrich(c, today: TODAY)
    [c.reload, client]
  end

  test "modèle par défaut : Haiku 5.5 ; escalade par défaut : Sonnet 5.5" do
    avec_env("VEILLE_MODEL" => nil, "VEILLE_MODEL_ESCALADE" => nil) do
      assert_equal "claude-haiku-5-5", Veille::AiEnricher.model
      assert_equal "claude-sonnet-5-5", Veille::AiEnricher.model_escalade
    end
    avec_env("VEILLE_MODEL" => nil, "VEILLE_MODEL_ESCALADE" => "claude-opus-5-5") { assert_equal "claude-opus-5-5", Veille::AiEnricher.model_escalade }
  end

  test "VEILLE_MODEL et VEILLE_MODEL_ESCALADE changent les modèles appelés" do
    avec_env("VEILLE_MODEL" => "modele-a", "VEILLE_MODEL_ESCALADE" => "modele-b") do
      c, client = enrichir(candidat, reponse_ia(confiance: 55), reponse_ia(confiance: 85))
      assert_equal %w[modele-a modele-b], client.calls.map { |k| k[:model] }
      assert_equal %w[modele-a modele-b], c.appels_ia.order(:id).map(&:modele)
      assert_equal %w[enrichissement escalade], c.appels_ia.order(:id).map(&:passe)
    end
  end

  test "score sûr (hors 40-70) : un seul passage" do
    [20, 39, 71, 95].each do |score|
      c, client = enrichir(candidat, reponse_ia(confiance: score))
      assert_equal 1, client.calls.size, "score #{score}"
      assert_equal 1, c.appels_ia.count
    end
  end

  test "score incertain (bornes 40 et 70 comprises) : second passage dont l'avis remplace le premier" do
    [40, 55, 70].each do |score|
      c, client = enrichir(candidat, reponse_ia(confiance: score, resume: "Premier avis. Deux."),
                                      reponse_ia(confiance: 90, resume: "Second avis. Deux.", motif: "Tranché."))
      assert_equal 2, client.calls.size, "score #{score}"
      assert_equal 90, c.score
      assert_equal "Second avis. Deux.", c.summary
      assert_match "Second avis (claude-sonnet-5-5, premier score #{score}, premier verdict", c.reason
    end
  end

  test "un élément écarté au premier passage revient dans la file si l'escalade le juge pertinent" do
    c, = enrichir(candidat, reponse_ia(confiance: 50, hors_ligne: true, motif: "Actualité."),
                            reponse_ia(confiance: 85, hors_ligne: false))
    assert_equal "a_verifier", c.status, "Haiku écartait, Sonnet garde : divergence, donc à vérifier"
    assert_match "divergent", c.reason
    assert_nil c.discard_reason
  end

  test "escalade désactivée si les deux modèles sont identiques" do
    avec_env("VEILLE_MODEL" => "m", "VEILLE_MODEL_ESCALADE" => "m") do
      _, client = enrichir(candidat, reponse_ia(confiance: 55))
      assert_equal 1, client.calls.size
    end
  end

  test "effort bas pour les modèles 5.x, absent pour les anciens" do
    assert_equal "low", Veille::AiEnricher.params_pour("claude-sonnet-5-5", Veille::AiEnricher.prompt_for(title: "T", text: "x"))[:output_config][:effort]
    ancien = Veille::AiEnricher.params_pour("claude-haiku-4-5-20251001", Veille::AiEnricher.prompt_for(title: "T", text: "x"))
    assert_nil ancien[:output_config][:effort]
    assert_equal "json_schema", ancien[:output_config][:format][:type]
  end

  test "tarifs 5.5 : Haiku 0,10/0,50, Sonnet 2/10, Opus 4/20 ; les anciens modèles gardent leurs tarifs" do
    u = { "input_tokens" => 1_000_000, "output_tokens" => 1_000_000 }
    assert_in_delta 0.6,  Veille::Cout.estimer("claude-haiku-5-5", u), 0.0001
    assert_in_delta 12.0, Veille::Cout.estimer("claude-sonnet-5-5", u), 0.0001
    assert_in_delta 24.0, Veille::Cout.estimer("claude-opus-5-5", u), 0.0001
    assert_in_delta 6.0,  Veille::Cout.estimer("claude-haiku-4-5-20251001", u), 0.0001
  end
end
