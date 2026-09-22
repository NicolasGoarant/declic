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
end
