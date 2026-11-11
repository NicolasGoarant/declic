require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

class Veille::BancEssaiTest < ActiveSupport::TestCase
  include VeilleSupport

  def candidat(origine, titre, texte = "")
    Veille::Candidate.create!(origin: origine, url: "https://exemple.fr/#{SecureRandom.hex(3)}", title: titre, full_text: texte, fetched_at: Time.current)
  end

  test "refuse les origines dont les CGU s'opposent à l'IA, sauf autorisation écrite déclarée" do
    candidat("ici_lorraine", "Nancy : appel à bénévoles")
    banc = Veille::BancEssai.new(client: Object.new)
    assert_raises(Veille::BancEssai::OrigineInterdite) { banc.choisir({ "ici_lorraine" => 5 }) }
    assert_raises(Veille::BancEssai::OrigineInterdite) { banc.choisir({ "france3_lorraine" => 5 }) }
    assert_equal 1, banc.choisir({ "ici_lorraine" => 5 }, autorisation: true).size
  end

  test "choisit d'abord les éléments retenus par le préfiltre, puis complète" do
    ecarte = candidat("agenda_nancy", "Paris : un match")
    retenu = candidat("agenda_nancy", "Nancy : appel à bénévoles")
    assert_equal [retenu, ecarte], Veille::BancEssai.new(client: Object.new).choisir({ "agenda_nancy" => 2 })
    assert_equal [retenu], Veille::BancEssai.new(client: Object.new).choisir({ "agenda_nancy" => 1 })
  end

  test "compare deux modèles, mesure jetons et coût, exporte le CSV avec la colonne avis vide" do
    c = candidat("agenda_nancy", "Nancy : appel à bénévoles")
    client = FakeAnthropicClient.new(text: reponse_ia(confiance: 80).merge("famille" => "s_engager", "role_public" => "contributeur", "zone" => "grand_nancy",
                                                                            "lieu" => "", "date_debut" => "", "date_fin" => "", "regime" => "").to_json,
                                     usage: { "input_tokens" => 1_000_000, "output_tokens" => 100_000 })
    banc = Veille::BancEssai.new(client: client)
    lignes = banc.run([c])

    assert_equal %w[claude-haiku-5-5 claude-sonnet-5-5], client.calls.map { |k| k[:model] }
    assert_in_delta 0.15, lignes.first.a.cout, 0.0001
    assert_in_delta 3.0, lignes.first.b.cout, 0.0001
    assert Veille::BancEssai.accord?(lignes.first)
    r = Veille::BancEssai.resume(lignes)
    assert_equal [100.0, 15.0, 300.0], [r[:accord_pct], r[:cout_a_100], r[:cout_b_100]]

    csv = CSV.parse(Veille::BancEssai.csv(lignes), headers: true)
    assert_equal Veille::BancEssai::COLONNES, csv.headers
    assert_equal ["80", "80"], [csv[0]["score Haiku"], csv[0]["score Sonnet"]]
    assert csv[0]["avis de Nicolas"].blank?
  end

  test "une erreur d'API sur un élément n'arrête pas le banc" do
    c = candidat("agenda_nancy", "Nancy : appel")
    client = FakeAnthropicClient.new(raise_with: AnthropicClient::Error.new("panne"))
    ligne = Veille::BancEssai.new(client: client).run([c]).first
    assert_match "panne", ligne.a.erreur
    assert_not Veille::BancEssai.accord?(ligne)
  end
end
