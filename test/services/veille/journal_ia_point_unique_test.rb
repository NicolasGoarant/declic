require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

# Point unique de journalisation : toute origine d'appel écrit une ligne complète.
class Veille::JournalIaPointUniqueTest < ActiveSupport::TestCase
  include VeilleSupport

  USAGE = { "input_tokens" => 1_000_000, "output_tokens" => 100_000 }.freeze

  test "un appel simulé crée une ligne complète : modèle, jetons, coût, origine, durée" do
    client = FakeAnthropicClient.new(text: "{}", usage: USAGE)
    Veille::JournalIa.appeler(passe: "enrichissement", modele: "claude-sonnet-5-5", origine: "ai_ping") { client.messages(messages: []) }

    ligne = Veille::AppelIa.sole
    assert_equal ["enrichissement", "claude-sonnet-5-5", "ok", "ai_ping"], [ligne.passe, ligne.modele, ligne.statut, ligne.origine]
    assert_equal [1_000_000, 100_000], [ligne.input_tokens, ligne.output_tokens]
    assert_in_delta 3.0, ligne.cout_usd.to_f, 0.0001
    assert_not_nil ligne.duree_ms
  end

  test "le banc d'essai journalise ses appels (origine banc_essai) et ils comptent dans le plafond" do
    c = Veille::Candidate.create!(origin: "agenda_nancy", url: "https://exemple.fr/x", title: "Nancy : appel à bénévoles", fetched_at: Time.current)
    client = FakeAnthropicClient.new(text: reponse_ia.to_json, usage: USAGE)
    Veille::BancEssai.new(client: client).run([c])

    assert_equal %w[banc_essai banc_essai], Veille::AppelIa.pluck(:origine)
    assert_in_delta 3.15, Veille::Plafond.depense, 0.0001
  end

  test "le tri (AiPass) passe par le même point et garde l'origine par défaut" do
    Veille::AiEnricher.new(client: FakeAnthropicClient.new(text: reponse_ia.to_json, usage: USAGE)).enrich(candidat)
    assert_equal "veille", Veille::AppelIa.sole.origine
  end

  test "reporter lit les jetons et coûts du CSV, une seule fois" do
    csv = Tempfile.new(["banc", ".csv"])
    csv.write(Veille::BancEssai::COLONNES.join(",") + "\n")
    csv.write("T,https://x,agenda_nancy,opportunité,80,1000/200,0.00020,opportunité,80,1000/300,0.00500,oui,\n")
    csv.flush
    jour = Date.new(2026, 11, 11)

    assert_equal 2, Veille::BancEssai.reporter(csv.path, date: jour)
    assert_equal 0, Veille::BancEssai.reporter(csv.path, date: jour)
    assert_equal %w[banc_essai banc_essai], Veille::AppelIa.pluck(:origine)
    assert_in_delta 0.0052, Veille::Plafond.depense(jour), 0.000001
  end
end
