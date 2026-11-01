require "test_helper"
require_relative "support"

class Veille::ValidationTest < ActiveSupport::TestCase
  include VeilleSupport

  setup do
    Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
    Geocoder::Lookup::Test.add_stub("Laxou", [{ "latitude" => 48.6936, "longitude" => 6.1496, "address" => "Laxou" }])
  end

  test "une opportunité validée est créée en ligne, avec lien vers l'origine" do
    c = candidat(item_type: "opportunite", declic_category: "formation", commune: "Nancy", summary: "Deux phrases. Voilà.",
                 starts_on: Date.new(2027, 1, 20), url: "https://exemple.fr/formation")

    opp = Veille::Validation.new(c).call

    assert opp.is_active, "publiée par le geste de validation"
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

  test "la famille passe du candidat à la fiche, sauf hors_ligne" do
    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Une phrase. Une autre.", famille: "petite_manifestation")
    assert_equal "petite_manifestation", Veille::Validation.new(c).call.famille

    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Une phrase. Une autre.", famille: "hors_ligne")
    assert_nil Veille::Validation.new(c).call.famille
  end

  test "une mission sans date garde son régime" do
    c = candidat(item_type: "opportunite", declic_category: "benevolat", commune: "Nancy", summary: "Aider.", schedule_text: "Ouvert toute l'année")
    opp = Veille::Validation.new(c).call
    assert opp.permanente?
    assert_equal "Ouvert toute l'année", opp.schedule_text
  end

  test "une belle histoire validée avec l'accord devient une Story en ligne avec son récit" do
    c = candidat(origin: "presse", item_type: "belle_histoire", commune: "Laxou", accord_obtenu_at: Time.current,
                 summary: "Un résumé.", draft_body: "Un récit.\n\nSource : Presse locale\nAccord de la personne : obtenu le 01/11/2026")

    story = Veille::Validation.new(c).call

    assert_kind_of Story, story
    assert story.is_active
    assert_includes story.body, "Accord de la personne : obtenu"
    assert_equal "Laxou", story.location
    assert_nil story.thematique
    assert_nil story.tags, "aucune étiquette de catégorie"
    assert_equal c.url, story.source_url
    assert_nil c.reload.full_text
    assert_equal "publie", c.status
  end

  test "un récit ne se publie ni sans l'accord de la personne, ni sans être rédigé" do
    sans_accord = candidat(item_type: "belle_histoire", commune: "Laxou", summary: "Un résumé.", draft_body: "Un récit.")
    sans_recit  = candidat(item_type: "belle_histoire", commune: "Laxou", summary: "Un résumé.", accord_obtenu_at: Time.current)

    assert_no_difference -> { Story.count } do
      assert_match(/accord/, assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(sans_accord).call }.message)
      assert_match(/rédigé/, assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(sans_recit).call }.message)
    end
    assert_equal %w[pending pending], [sans_accord.reload.status, sans_recit.reload.status]
  end

  test "un élément déjà publié ne crée pas de seconde fiche" do
    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Une phrase.")
    Veille::Validation.new(c).call
    assert_no_difference -> { Opportunity.count } do
      assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(c).call }
    end
  end

  test "valider ne touche pas à l'étiquette du candidat" do
    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Une phrase.")
    etiquette = Veille::Etiquette.create!(ref: "C#{c.id}", avis: "garder")
    Veille::Validation.new(c).call
    assert_equal "garder", etiquette.reload.avis
  end

  test "une fiche invalide ne change pas le statut du candidat" do
    c = candidat(item_type: "opportunite", commune: nil, summary: nil, excerpt: nil)
    assert_no_difference -> { Opportunity.count } do
      assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(c).call }
    end
    assert_equal "pending", c.reload.status
  end
end
