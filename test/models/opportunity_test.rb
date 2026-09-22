require "test_helper"

class OpportunityTest < ActiveSupport::TestCase
  def build_opportunity(location:)
    Opportunity.new(
      title: "Test",
      description: "d" * 150,
      category: "benevolat",
      location: location
    )
  end

  test "un résultat proche de Nancy est conservé" do
    Geocoder::Lookup::Test.add_stub("27 Rue de la République, 54000 Nancy", [
      { "latitude" => 48.6937, "longitude" => 6.1834, "address" => "27 Rue de la République, Nancy" }
    ])

    o = build_opportunity(location: "27 Rue de la République, 54000 Nancy")
    o.geocode_and_guard

    assert_in_delta 48.6937, o.latitude, 0.001
    assert_in_delta 6.1834, o.longitude, 0.001
    assert_nil o.geocoding_flagged_reason
  end

  test "le garde-fou rejette le cas connu — MJC Desforges géocodée dans le Loiret" do
    # Le cas qui a déclenché ce garde-fou : une adresse réelle à Nancy,
    # géocodée à 279 km de là parce que Nominatim a pris « Desforges » pour
    # un toponyme du Loiret.
    Geocoder::Lookup::Test.add_stub("MJC Desforges, Nancy", [
      { "latitude" => 47.630863, "longitude" => 2.663005, "address" => "Desforges, Loiret" }
    ])

    o = build_opportunity(location: "MJC Desforges, Nancy")
    o.geocode_and_guard

    assert_nil o.latitude
    assert_nil o.longitude
    assert_match(/rejeté/, o.geocoding_flagged_reason)
    assert_match(/km de Nancy/, o.geocoding_flagged_reason)
  end

  test "un résultat à plus de 30 km est rejeté" do
    # Metz, à ~50 km de la place Stanislas : au-dessus du seuil.
    Geocoder::Lookup::Test.add_stub("adresse à Metz", [
      { "latitude" => 49.1193, "longitude" => 6.1757, "address" => "Metz" }
    ])

    o = build_opportunity(location: "adresse à Metz")
    o.geocode_and_guard

    assert_nil o.latitude
    assert_nil o.longitude
    assert o.geocoding_flagged_reason.present?
  end

  test "un résultat à moins de 30 km est conservé" do
    # Toul, à environ 22 km de la place Stanislas : sous le seuil.
    Geocoder::Lookup::Test.add_stub("adresse à Toul", [
      { "latitude" => 48.6769, "longitude" => 5.8899, "address" => "Toul" }
    ])

    o = build_opportunity(location: "adresse à Toul")
    o.geocode_and_guard

    assert o.latitude.present?
    assert o.longitude.present?
    assert_nil o.geocoding_flagged_reason
  end

  test "un rejet efface les anciennes coordonnées au lieu de les garder" do
    Geocoder::Lookup::Test.add_stub("adresse à Metz", [
      { "latitude" => 49.1193, "longitude" => 6.1757, "address" => "Metz" }
    ])

    o = build_opportunity(location: "adresse à Metz")
    o.latitude = 48.6937
    o.longitude = 6.1834
    o.geocode_and_guard

    assert_nil o.latitude, "un résultat rejeté ne doit pas laisser d'anciennes coordonnées en place"
    assert_nil o.longitude
  end

  test "distance_to_nancy_km et far_from_nancy? sur le point de référence lui-même" do
    o = build_opportunity(location: "place Stanislas")
    o.latitude = 48.6937
    o.longitude = 6.1834

    assert_in_delta 0.0, o.distance_to_nancy_km, 0.01
    assert_not o.far_from_nancy?
  end

  test "distance_to_nancy_km est nil sans coordonnées" do
    o = build_opportunity(location: "sans coordonnées")
    assert_nil o.distance_to_nancy_km
    assert_not o.far_from_nancy?
  end
end
