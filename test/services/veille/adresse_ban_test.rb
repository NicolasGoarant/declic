require "test_helper"
require_relative "support"

class Veille::AdresseBanTest < ActiveSupport::TestCase
  include VeilleSupport

  def self.reponse(city: "Nancy", score: 0.97, type: "housenumber", coords: [6.181748, 48.691955])
    { features: [{ geometry: { coordinates: coords },
                   properties: { label: "15 Rue Saint Dizier 54000 Nancy", score: score, type: type, city: city } }] }.to_json
  end

  def installer(corps)
    http = VeilleSupport::FakeHttp.new
    http.define_singleton_method(:get) { |url, **o| @appels << url; corps.is_a?(Exception) ? raise(corps) : corps }
    Veille::AdresseBan.client = http
    http
  end

  test "une adresse précise donne le point de l'adresse" do
    http = installer(self.class.reponse)
    r = Veille::AdresseBan.localiser("15 rue Saint-Dizier", "Nancy")
    assert_in_delta 48.691955, r.latitude, 1e-6
    assert_in_delta 6.181748, r.longitude, 1e-6
    assert_includes http.appels.first, "api-adresse.data.gouv.fr/search/"
    assert_includes http.appels.first, "15+rue+Saint-Dizier+Nancy"
  end

  test "adresse vide : aucun appel" do
    http = installer(self.class.reponse)
    assert_nil Veille::AdresseBan.localiser("  ", "Nancy")
    assert_empty http.appels
  end

  test "résultat refusé : trop approximatif, centre de commune, autre commune, aucun, panne" do
    installer(self.class.reponse(score: 0.3))
    assert_nil Veille::AdresseBan.localiser("rue du Vide", "Nancy")
    installer(self.class.reponse(type: "municipality"))
    assert_nil Veille::AdresseBan.localiser("Nancy centre", "Nancy")
    installer(self.class.reponse(city: "Laxou"))
    assert_nil Veille::AdresseBan.localiser("15 rue Saint-Dizier", "Nancy")
    installer({ features: [] }.to_json)
    assert_nil Veille::AdresseBan.localiser("zzz", "Nancy")
    installer("pas du json")
    assert_nil Veille::AdresseBan.localiser("15 rue Saint-Dizier", "Nancy")
    installer(Veille::Http::Error.new("HTTP 503"))
    assert_nil Veille::AdresseBan.localiser("15 rue Saint-Dizier", "Nancy")
  end
end
