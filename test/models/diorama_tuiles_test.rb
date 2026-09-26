require "test_helper"

class DioramaTuilesTest < ActiveSupport::TestCase
  # Une base différente par test : le cache de sonde est indexé par base.
  def tuiles(presentes)
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    DioramaTuiles.new(base: base, sonde: ->(url) { presentes.any? { |p| url == "#{base}/#{p}" } })
  end

  test "seul le lot toits-v1 : pas de maquette blanche ni d'ambiance" do
    assert_equal({ vrai: true, blanche: false, ambiances: [] }, tuiles(["toits-v1/manifeste.json"]).disponibles)
  end

  test "la maquette blanche exige le lot et le masque" do
    t = tuiles(["toits-v1/manifeste.json", "masque-bati/manifeste.json"])
    assert t.disponibles[:blanche]
    assert_empty t.disponibles[:ambiances]
  end

  test "une ambiance exige blanche, propriété et son propre fichier" do
    t = tuiles(%w[toits-v1/manifeste.json masque-bati/manifeste.json toits-v1-propriete/manifeste.json
                  ambiances/hiver-actuelle.json])
    assert_equal %w[hiver], t.disponibles[:ambiances]
  end

  test "sans le lot, rien n'est disponible" do
    assert_equal({ vrai: false, blanche: false, ambiances: [] }, tuiles(["masque-bati/manifeste.json"]).disponibles)
  end

  test "la base vient de DIORAMA_TILES_URL, sinon du domaine par défaut" do
    assert_equal DioramaTuiles::URL_DEFAUT, DioramaTuiles.new(sonde: ->(_) { false }).base unless ENV["DIORAMA_TILES_URL"].present?
    assert_equal "https://ailleurs.test", DioramaTuiles.new(base: "https://ailleurs.test/", sonde: ->(_) { false }).base
  end
end
