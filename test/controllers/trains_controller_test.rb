require "test_helper"
require "minitest/mock"

class TrainsControllerTest < ActionDispatch::IntegrationTest
  test "prochains rend du JSON avec l'heure du serveur, même si le relais lève une erreur" do
    Trains::TripUpdates.stub(:lire, -> { raise "boum" }) do
      get trains_prochains_path
    end
    assert_response :success
    corps = response.parsed_body
    assert_equal [], corps["passages"]
    assert_kind_of Integer, corps["maintenant"]
  end

  test "prochains rend la liste telle que Prochains la calcule" do
    Trains::Prochains.stub(:liste, ->(_) { { passages: [{ id: "x" }], theorique: true, temps_reel: false } }) do
      get trains_prochains_path
    end
    assert_equal "x", response.parsed_body["passages"][0]["id"]
    assert_equal false, response.parsed_body["temps_reel"]
  end

  test "prochains accepte une heure d'essai (?a=HH:MM) hors production" do
    vue = nil
    Trains::Prochains.stub(:liste, ->(m) { vue = m; { passages: [], theorique: true, temps_reel: false } }) do
      get trains_prochains_path(a: "08:15")
    end
    assert_equal "08:15", vue.in_time_zone("Europe/Paris").strftime("%H:%M")
    assert_equal vue.to_i, response.parsed_body["maintenant"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
