require "test_helper"

class StoryTest < ActiveSupport::TestCase
  def build_story(location:)
    Story.new(title: "Test", location: location)
  end

  test "un résultat proche de Nancy est conservé" do
    Geocoder::Lookup::Test.add_stub("27 Rue de la République, 54000 Nancy", [
      { "latitude" => 48.6937, "longitude" => 6.1834, "address" => "27 Rue de la République, Nancy" }
    ])

    s = build_story(location: "27 Rue de la République, 54000 Nancy")
    s.geocode_and_guard

    assert_in_delta 48.6937, s.latitude, 0.001
    assert_in_delta 6.1834, s.longitude, 0.001
    assert_nil s.geocoding_flagged_reason
  end

  test "le garde-fou rejette le cas connu — MJC Desforges géocodée dans le Loiret" do
    Geocoder::Lookup::Test.add_stub("MJC Desforges, Nancy", [
      { "latitude" => 47.630863, "longitude" => 2.663005, "address" => "Desforges, Loiret" }
    ])

    s = build_story(location: "MJC Desforges, Nancy")
    s.geocode_and_guard

    assert_nil s.latitude
    assert_nil s.longitude
    assert_match(/rejeté/, s.geocoding_flagged_reason)
    assert_match(/km de Nancy/, s.geocoding_flagged_reason)
  end

  test "un résultat à plus de 30 km est rejeté" do
    Geocoder::Lookup::Test.add_stub("adresse à Metz", [
      { "latitude" => 49.1193, "longitude" => 6.1757, "address" => "Metz" }
    ])

    s = build_story(location: "adresse à Metz")
    s.geocode_and_guard

    assert_nil s.latitude
    assert_nil s.longitude
    assert s.geocoding_flagged_reason.present?
  end

  test "un résultat à moins de 30 km est conservé" do
    Geocoder::Lookup::Test.add_stub("adresse à Toul", [
      { "latitude" => 48.6769, "longitude" => 5.8899, "address" => "Toul" }
    ])

    s = build_story(location: "adresse à Toul")
    s.geocode_and_guard

    assert s.latitude.present?
    assert s.longitude.present?
    assert_nil s.geocoding_flagged_reason
  end

  test "un rejet efface les anciennes coordonnées au lieu de les garder" do
    Geocoder::Lookup::Test.add_stub("adresse à Metz", [
      { "latitude" => 49.1193, "longitude" => 6.1757, "address" => "Metz" }
    ])

    s = build_story(location: "adresse à Metz")
    s.latitude = 48.6937
    s.longitude = 6.1834
    s.geocode_and_guard

    assert_nil s.latitude, "un résultat rejeté ne doit pas laisser d'anciennes coordonnées en place"
    assert_nil s.longitude
  end

  def candidat(**attrs)
    Veille::Candidate.create!({
      url:       "https://exemple.fr/article-#{SecureRandom.hex(4)}",
      title:     "Un titre",
      full_text: "Le texte intégral de l'article de presse, mot pour mot.",
      status:    "retenu"
    }.merge(attrs))
  end

  # ------------------------------------------------------------------
  # La règle centrale du chantier.
  # ------------------------------------------------------------------
  test "créer la fiche efface full_text du candidat" do
    c = candidat
    assert c.full_text?, "préalable : le tampon est rempli"

    Story.create!(title: "Une belle histoire", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: c)

    assert_nil c.reload.full_text,
               "full_text est un tampon de travail : Déclic ne constitue pas " \
               "de base dérivée d'articles de presse"
    assert_not c.full_text?
  end

  test "la purge conserve tout le reste du candidat" do
    c = candidat(excerpt: "Le chapeau", score: 88, category: "belle_histoire", reason: "Motif")
    url_avant = c.url

    Story.create!(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: c)
    c.reload

    assert_equal "Le chapeau", c.excerpt
    assert_equal 88, c.score
    assert_equal "belle_histoire", c.category
    assert_equal "Motif", c.reason
    assert_equal url_avant, c.url, "le lien vers la source est ce qu'on garde"
  end

  test "la purge n'écrase pas une fiche sans candidat" do
    assert_nothing_raised { Story.create!(title: "Histoire saisie à la main", location: "Nancy", latitude: 48.69, longitude: 6.18) }
  end

  test "la purge est sans effet si le tampon est déjà vide" do
    c = candidat(full_text: nil)
    story = Story.create!(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: c)

    assert_nil c.reload.full_text
    assert_equal c, story.veille_candidate
  end

  test "le lien candidat vers fiche fonctionne dans les deux sens" do
    c = candidat
    story = Story.create!(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: c)

    assert_equal story, c.reload.story
    assert_equal c, story.veille_candidate
  end

  test "supprimer le candidat ne détruit pas la fiche publiée" do
    c = candidat
    story = Story.create!(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: c)

    c.destroy
    assert Story.exists?(story.id), "une histoire publiée survit à son candidat"
    assert_nil story.reload.veille_candidate_id
  end

  test "la fiche issue de la veille naît inactive" do
    story = Story.create!(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: candidat)
    assert_not story.is_active, "elle est relue en admin avant publication"
  end
end
