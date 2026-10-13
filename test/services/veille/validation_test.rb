require "test_helper"
require_relative "support"

class Veille::ValidationTest < ActiveSupport::TestCase
  include VeilleSupport

  setup do
    Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
    Geocoder::Lookup::Test.add_stub("Laxou", [{ "latitude" => 48.6936, "longitude" => 6.1496, "address" => "Laxou" }])
  end

  test "une opportunité validée devient un brouillon hors ligne, avec lien vers l'origine" do
    c = candidat(item_type: "opportunite", declic_category: "formation", commune: "Nancy", summary: "Deux phrases. Voilà.",
                 starts_on: Date.new(2027, 1, 20), url: "https://exemple.fr/formation")

    opp = Veille::Validation.new(c).call

    assert_not opp.is_active, "jamais publiée automatiquement"
    assert_equal "formation", opp.category
    assert_equal "Nancy", opp.location
    assert_equal Date.new(2027, 1, 20), opp.starts_on
    assert_equal "https://exemple.fr/formation", opp.cta_button_url
    assert_equal "Pour en savoir plus", opp.cta_button_text
    assert_includes opp.description, "Deux phrases. Voilà."
    assert_not_includes opp.description, "Un texte source."

    c.reload
    assert_equal "publie", c.status
    assert_equal opp, c.opportunity
    assert_nil c.full_text, "le texte brut est effacé une fois la fiche créée"
  end

  test "une mission sans date garde son régime" do
    c = candidat(item_type: "opportunite", declic_category: "benevolat", commune: "Nancy", summary: "Aider.", schedule_text: "Ouvert toute l'année")
    opp = Veille::Validation.new(c).call
    assert opp.permanente?
    assert_equal "Ouvert toute l'année", opp.schedule_text
  end

  test "une belle histoire validée devient une Story inactive avec le brouillon" do
    c = candidat(origin: "presse", item_type: "belle_histoire", declic_category: "entreprendre", commune: "Laxou",
                 summary: "Un résumé.", draft_body: "Un récit.\n\nSource : Presse locale\nAccord de la personne : à obtenir")

    story = Veille::Validation.new(c).call

    assert_kind_of Story, story
    assert_not story.is_active
    assert_includes story.body, "Accord de la personne : à obtenir"
    assert_equal "Laxou", story.location
    assert_equal c.url, story.source_url
    assert_nil c.reload.full_text
    assert_equal "publie", c.status
  end

  test "sans brouillon, la belle histoire reçoit quand même les mentions obligatoires" do
    c = candidat(origin: "presse", item_type: "belle_histoire", commune: "Laxou", summary: "Un résumé.")
    story = Veille::Validation.new(c).call
    assert_includes story.body, "Accord de la personne : à obtenir"
    assert_includes story.body, c.url
  end

  test "une fiche invalide ne change pas le statut du candidat" do
    c = candidat(item_type: "opportunite", commune: nil, summary: nil, excerpt: nil)
    assert_no_difference -> { Opportunity.count } do
      assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(c).call }
    end
    assert_equal "pending", c.reload.status
  end
end
