require "test_helper"
require_relative "support"

class Veille::LieuOsmTest < ActiveSupport::TestCase
  include VeilleSupport

  def self.reponse(ville: "Nancy", lat: "48.6936593", lon: "6.1818995")
    [{ lat: lat, lon: lon, display_name: "Musée des Beaux-Arts, Nancy", address: { city: ville } }].to_json
  end

  def installer(corps)
    http = VeilleSupport::FakeHttp.new
    http.define_singleton_method(:get) { |url, **o| @appels << url; corps.is_a?(Exception) ? raise(corps) : corps }
    Veille::LieuOsm.client = http
    http
  end

  test "un lieu nommé donne son point, requête bornée au Grand Nancy" do
    http = installer(self.class.reponse)
    r = Veille::LieuOsm.localiser("Musée des Beaux-Arts", "Nancy")
    assert_in_delta 48.6936593, r.latitude, 1e-6
    assert_in_delta 6.1818995, r.longitude, 1e-6
    assert_includes http.appels.first, "bounded=1"
    assert_includes http.appels.first, "nominatim.openstreetmap.org"
  end

  test "un lieu d'une commune homonyme voisine est refusé" do
    installer(self.class.reponse(ville: "Laxou"))
    assert_nil Veille::LieuOsm.localiser("Musée des Beaux-Arts", "Nancy")
  end

  test "lieu vide, réponse vide ou service en panne : nil, sans lever" do
    assert_nil Veille::LieuOsm.localiser("", "Nancy")
    installer("[]")
    assert_nil Veille::LieuOsm.localiser("Nulle part", "Nancy")
    installer(Veille::Http::Error.new("panne"))
    assert_nil Veille::LieuOsm.localiser("Musée des Beaux-Arts", "Nancy")
  end
end
