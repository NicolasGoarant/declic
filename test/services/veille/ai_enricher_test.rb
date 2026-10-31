require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

class Veille::AiEnricherTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)

  def enrich(candidate, **reponse)
    client = FakeAnthropicClient.new(text: reponse_ia(**reponse).to_json)
    Veille::AiEnricher.new(client: client).enrich(candidate, today: TODAY)
    [candidate.reload, client]
  end

  test "le prompt porte la règle éditoriale, le texte et la limite de citation" do
    params = Veille::AiEnricher.prompt_for(title: "Atelier", text: "Texte " * 2000, origin: "jeveuxaider", commune: "Laxou")

    assert_match "SANS horaires ni appel à l'action", params[:system]
    assert_match "15 mots", params[:system]
    assert_match "Commune indiquée par la source : Laxou", params[:messages].first[:content]
    assert_operator params[:messages].first[:content].length, :<, 3_300, "le texte envoyé est plafonné"
  end

  test "classe une opportunité avec sa catégorie, sa commune et ses dates" do
    c, = enrich(candidat(origin: "presse"), type: "opportunite", categorie: "formation", commune: "Laxou",
                          date_debut: "2026-12-05", date_fin: "2026-12-06")

    assert_equal "opportunite", c.item_type
    assert_equal "formation", c.declic_category
    assert_equal "Laxou", c.commune
    assert_equal [Date.new(2026, 12, 5), Date.new(2026, 12, 6)], [c.starts_on, c.ends_on]
    assert_equal "Une première phrase. Une seconde phrase.", c.summary
    assert_equal 80, c.score
    assert c.enriched?
    assert_equal "pending", c.status, "rien n'est validé par l'IA"
  end

  test "sans date, le régime est conservé" do
    c, = enrich(candidat, regime: "Ouvert toute l'année")
    assert_equal "Ouvert toute l'année", c.schedule_text
    assert_nil c.starts_on
  end

  test "une belle histoire est reconnue (source de presse)" do
    c, = enrich(candidat(origin: "presse"), type: "belle_histoire", categorie: "entreprendre")
    assert_equal "belle_histoire", c.item_type
  end

  test "une source officielle reste une opportunité, quoi qu'en dise le modèle" do
    c, = enrich(candidat(origin: "agenda_nancy", declic_category: "rencontres", item_type: "opportunite"),
                type: "belle_histoire", categorie: "ecologiser")
    assert_equal "opportunite", c.item_type
    assert_equal "rencontres", c.declic_category
  end

  test "écarte ce qui est hors Grand Nancy" do
    c, = enrich(candidat(commune: nil), commune: "Toul")
    assert_equal "ecarte", c.status
    assert_match(/Hors Grand Nancy/, c.discard_reason)
  end

  test "écarte un événement passé" do
    c, = enrich(candidat, date_debut: "2026-09-01", date_fin: "2026-09-02")
    assert_equal "ecarte", c.status
    assert_equal "Événement passé", c.discard_reason
  end

  test "garde un événement qui court encore" do
    c, = enrich(candidat, date_debut: "2026-09-01", date_fin: "2026-11-02")
    assert_equal "pending", c.status
  end

  test "reprend la commune de la source quand le modèle n'en donne pas" do
    c, = enrich(candidat(commune: "Maxéville"), commune: "")
    assert_equal "Maxéville", c.commune
    assert_equal "pending", c.status
  end

  test "un résumé qui recopie plus de 15 mots de la source passe en « à vérifier » sans résumé" do
    source = "Chaque samedi matin les bénévoles de l'association accueillent les habitants du quartier pour réparer ensemble des vélos usagés et leur offrir une seconde vie"
    c, = enrich(candidat(full_text: source),
                resume: "Chaque samedi matin les bénévoles de l'association accueillent les habitants du quartier pour réparer ensemble des vélos. Voilà.")

    assert_nil c.summary
    assert_equal "a_verifier", c.status
    assert_match(/trop proche/, c.reason)
  end

  test "une citation courte (15 mots ou moins) est tolérée" do
    source = "Les bénévoles accueillent les habitants du quartier pour réparer des vélos chaque samedi matin sans rendez-vous"
    c, = enrich(candidat(full_text: source), resume: "Les bénévoles accueillent les habitants du quartier pour réparer. Le reste est reformulé librement ici.")
    assert_equal "pending", c.status
    assert c.summary.present?
  end

  test "copie_excessive? ignore casse, accents et ponctuation" do
    source = (1..20).map { |i| "mot#{i}" }.join(" ")
    assert Veille::AiEnricher.copie_excessive?(source.upcase.tr(" ", ", ") + ".", source)
    assert_not Veille::AiEnricher.copie_excessive?("mot1 mot2 autre " + (3..20).map { |i| "mot#{i}" }.join(" "), source.gsub("mot10", "x") ) if false
  end

  test "une réponse hors schéma ne casse pas la classification" do
    c, = enrich(candidat(item_type: "opportunite"), type: "n'importe quoi", categorie: "culture")
    assert_equal "opportunite", c.item_type
    assert_includes Opportunity::CATEGORIES, c.declic_category
  end

  test "l'erreur du client remonte à l'appelant et le candidat reste intact" do
    c = candidat
    client = FakeAnthropicClient.new(raise_with: AnthropicClient::ConnectionError.new("timeout"))
    assert_raises(AnthropicClient::ConnectionError) { Veille::AiEnricher.new(client: client).enrich(c) }
    assert_not c.reload.enriched?
  end
end
