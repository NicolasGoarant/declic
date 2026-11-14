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

  test "les dates, heures et périodicité du candidat passent à la fiche, qui reste en ligne jusqu'à la fin du créneau" do
    c = candidat(item_type: "opportunite", declic_category: "decouvrir", commune: "Nancy", summary: "Deux phrases. Voilà.",
                 starts_on: Date.new(2026, 10, 10), ends_on: Date.new(2027, 3, 28), schedule_text: "tous les samedis et dimanches",
                 start_time: Time.utc(2000, 1, 1, 11), end_time: Time.utc(2000, 1, 1, 12))

    opp = Veille::Validation.new(c).call.reload

    assert_equal [Date.new(2026, 10, 10), Date.new(2027, 3, 28)], [opp.starts_on, opp.ends_on]
    assert_equal ["11:00", "12:00"], [opp.start_time, opp.end_time].map { |t| t.strftime("%H:%M") }
    assert_equal "tous les samedis et dimanches", opp.schedule_text
    en_ligne = ->(jour) { Opportunity.publiques(Time.find_zone("Europe/Paris").local(*jour, 12)).exists?(opp.id) }
    assert en_ligne.([2027, 3, 28]), "encore en ligne le dernier jour"
    assert_not en_ligne.([2027, 3, 30]), "retirée une fois le créneau terminé"
  end

  test "un candidat à l'ancienne catégorie « rencontres » reste enregistrable mais ne se valide pas avant d'être reclassé" do
    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Deux phrases. Voilà.")
    c.update_columns(declic_category: "rencontres")
    c.reload.update!(status: "a_verifier") # pas bloqué par la validation du modèle
    assert_match "n'existe plus", c.manque_pour_apercu
    erreur = assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(c).call }
    assert_match "reclasse", erreur.message
    c.classer("opportunite", "pratiquer").save!
    assert_equal "pratiquer", Veille::Validation.new(c).call.category
  end

  test "l'aperçu montre les mêmes dates que la fiche publiée" do
    c = candidat(item_type: "opportunite", commune: "Nancy", summary: "Deux phrases. Voilà.", starts_on: Date.new(2026, 11, 27),
                 ends_on: Date.new(2026, 11, 29), start_time: Time.utc(2000, 1, 1, 9, 30))
    apercu = Veille::Validation.new(c).apercu
    assert_equal [Date.new(2026, 11, 27), Date.new(2026, 11, 29)], [apercu.starts_on, apercu.ends_on]
    assert_equal "9h30", apercu.horaire_affiche
  end

  test "avec une adresse trouvée, le repère va à l'adresse et non au centre de la commune" do
    Veille::AdresseBan.client = Class.new { def get(*, **) = { features: [{ geometry: { coordinates: [6.2011, 48.6803] }, properties: { score: 0.95, type: "housenumber", city: "Nancy", label: "x" } }] }.to_json }.new
    c = candidat(item_type: "opportunite", commune: "Nancy", adresse: "12 rue Exemple", summary: "Une phrase. Une autre.")

    opp = Veille::Validation.new(c).call

    assert_equal [48.6803, 6.2011], [opp.latitude.to_f, opp.longitude.to_f]
    assert_equal "12 rue Exemple, Nancy", opp.location
    assert_equal "12 rue Exemple", opp.address
  end

  test "adresse introuvable ou API en panne : repli sur le centre de la commune, publication non bloquée" do
    c = candidat(item_type: "opportunite", commune: "Nancy", adresse: "12 rue Exemple", summary: "Une phrase. Une autre.")

    opp = Veille::Validation.new(c).call

    assert opp.is_active
    assert_equal "Nancy", opp.location
    assert_equal [48.6937, 6.1834], [opp.latitude.to_f, opp.longitude.to_f]
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

  test "une fiche invalide ne change pas le statut du candidat" do
    c = candidat(item_type: "opportunite", commune: nil, summary: nil, excerpt: nil)
    assert_no_difference -> { Opportunity.count } do
      assert_raises(Veille::Validation::Incomplet) { Veille::Validation.new(c).call }
    end
    assert_equal "pending", c.reload.status
  end

  test "un nom de lieu sans adresse postale est localisé via OSM : repère précis" do
    http = VeilleSupport::FakeHttp.new
    http.define_singleton_method(:get) { |*, **| { features: [] }.to_json }
    Veille::AdresseBan.client = http
    osm = VeilleSupport::FakeHttp.new
    osm.define_singleton_method(:get) do |*, **|
      [{ lat: "48.6936593", lon: "6.1818995", display_name: "Musée des Beaux-Arts", address: { city: "Nancy" } }].to_json
    end
    Veille::LieuOsm.client = osm

    c = candidat(item_type: "opportunite", declic_category: "decouvrir", commune: "Nancy", summary: "Deux phrases. Voilà.",
                 adresse: "Musée des Beaux-Arts", url: "https://exemple.fr/musee")
    opp = Veille::Validation.new(c).call

    assert_in_delta 48.6936593, opp.latitude, 1e-6
    assert_equal "Musée des Beaux-Arts", opp.address
  end

  test "lieu introuvable : repli sur la commune, la publication n'est pas bloquée" do
    c = candidat(item_type: "opportunite", declic_category: "decouvrir", commune: "Nancy", summary: "Deux phrases. Voilà.",
                 adresse: "Lieu inconnu", url: "https://exemple.fr/inconnu")
    opp = Veille::Validation.new(c).call
    assert_equal "publie", c.reload.status
    assert_in_delta 48.6937, opp.latitude, 1e-4, "centre de la commune"
  end
end
