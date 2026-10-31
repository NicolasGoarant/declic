require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

# Journal des appels (Veille::AppelIa) et plafond mensuel, via une vraie passe IA
# (AiEnricher) branchée sur la doublure du client.
class Veille::JournalIaTest < ActiveSupport::TestCase
  include VeilleSupport

  USAGE = { "input_tokens" => 1_000_000, "output_tokens" => 100_000 }.freeze # Haiku : 1 $ + 0,5 $

  def enricher(text: reponse_ia.to_json, raise_with: nil, usage: USAGE)
    Veille::AiEnricher.new(client: FakeAnthropicClient.new(text: text, raise_with: raise_with, usage: usage))
  end

  test "un appel réussi est journalisé avec sa consommation et son coût estimé" do
    c = candidat
    enricher.enrich(c)

    appel = c.appels_ia.sole
    assert_equal "ok", appel.statut
    assert_equal "enrichissement", appel.passe
    assert_equal Veille::AiEnricher::MODEL, appel.modele
    assert_equal [1_000_000, 100_000], [appel.input_tokens, appel.output_tokens]
    assert_in_delta 1.5, appel.cout_usd.to_f, 0.0001
    assert_not_nil appel.duree_ms
  end

  test "une erreur d'API est journalisée puis relancée" do
    c = candidat
    assert_raises(AnthropicClient::ConnectionError) do
      enricher(raise_with: AnthropicClient::ConnectionError.new("coupé")).enrich(c)
    end
    appel = c.appels_ia.sole
    assert_equal "erreur_api", appel.statut
    assert_match(/coupé/, appel.erreur)
    assert_equal 0, appel.cout_usd.to_f
  end

  test "une réponse illisible est journalisée avec son coût (les tokens ont été consommés)" do
    c = candidat
    assert_raises(Veille::AiPass::ParseError) { enricher(text: "pas du json").enrich(c) }
    appel = c.appels_ia.sole
    assert_equal "illisible", appel.statut
    assert_in_delta 1.5, appel.cout_usd.to_f, 0.0001
  end

  test "le plafond mensuel bloque l'appel avant tout envoi et le journalise" do
    Veille::AppelIa.create!(passe: "enrichissement", modele: "m", statut: "ok", cout_usd: 15.0)
    client = FakeAnthropicClient.new(text: reponse_ia.to_json)
    c = candidat

    assert_raises(Veille::Plafond::Depasse) { Veille::AiEnricher.new(client: client).enrich(c) }
    assert_empty client.calls, "aucun appel ne part une fois le plafond atteint"
    assert_equal "plafond", c.appels_ia.sole.statut
    assert_nil c.reload.enriched_at
  end

  test "sous le plafond, l'appel passe" do
    Veille::AppelIa.create!(passe: "enrichissement", modele: "m", statut: "ok", cout_usd: 14.99)
    assert_nothing_raised { enricher.enrich(candidat) }
  end

  test "le plafond se compte par mois civil" do
    Veille::AppelIa.create!(passe: "redaction", modele: "m", statut: "ok", cout_usd: 20.0, created_at: 1.month.ago.beginning_of_month + 1.day)
    assert_not Veille::Plafond.atteint?
    assert Veille::Plafond.atteint?(1.month.ago.to_date)
  end

  test "le plafond vaut 15 $ par défaut et se règle par VEILLE_BUDGET_USD_MOIS" do
    assert_equal 15.0, Veille::Plafond.budget
    avec_env("VEILLE_BUDGET_USD_MOIS" => "2.5") { assert_equal 2.5, Veille::Plafond.budget }
    avec_env("VEILLE_BUDGET_USD_MOIS" => "n'importe quoi") { assert_equal 15.0, Veille::Plafond.budget }
    avec_env("VEILLE_BUDGET_USD_MOIS" => "0") { assert_equal 15.0, Veille::Plafond.budget }
  end

  test "supprimer un candidat conserve son journal" do
    c = candidat
    enricher.enrich(c)
    assert_no_difference -> { Veille::AppelIa.count } do
      c.destroy!
    end
    assert_nil Veille::AppelIa.last.candidate_id
  end

  test "le Runner s'arrête proprement quand le plafond est atteint" do
    Veille::AppelIa.create!(passe: "redaction", modele: "m", statut: "ok", cout_usd: 99)
    3.times { |i| candidat(title: "T#{i}") }
    client = FakeAnthropicClient.new(text: reponse_ia.to_json)
    rapport = Veille::Runner.new(connecteurs: [], enricher: Veille::AiEnricher.new(client: client)).run

    assert rapport.plafond
    assert_equal 0, rapport.enrichis
    assert_empty client.calls
    assert_equal 3, Veille::Candidate.a_enrichir.count, "les candidats restent en file pour le mois suivant"
  end

  private

  def avec_env(vars)
    avant = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    avant.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
