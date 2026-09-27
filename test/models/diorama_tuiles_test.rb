require "test_helper"

class DioramaTuilesTest < ActiveSupport::TestCase
  # Une base différente par test : le cache de sonde est indexé par base.
  def tuiles(presentes)
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    DioramaTuiles.new(base: base, sonde: ->(url) { presentes.any? { |p| url == "#{base}/#{p}" } })
  end

  test "seul le lot toits-v1 : pas de maquette blanche ni d'ambiance" do
    assert_equal({ vrai: true, styles: %w[toits-v1], blanche: false, ambiances: [], arbres: false, lumieres: false },
                 tuiles([ "toits-v1/manifeste.json" ]).disponibles)
  end

  test "les deux styles publiés sont listés, jeu-video-v1 en tête" do
    t = tuiles(%w[toits-v1/manifeste.json jeu-video-v1/manifeste.json])
    assert_equal %w[jeu-video-v1 toits-v1], t.disponibles[:styles]
    assert_equal %w[jeu-video-v1 toits-v1], t.pour_js[:styles]
    assert_equal "jeu-video-v1", t.pour_js[:style_defaut]
  end

  test "la maquette blanche exige le lot et le masque" do
    t = tuiles([ "toits-v1/manifeste.json", "masque-bati/manifeste.json" ])
    assert t.disponibles[:blanche]
    assert_empty t.disponibles[:ambiances]
  end

  test "une ambiance exige blanche, propriété et son propre fichier" do
    t = tuiles(%w[toits-v1/manifeste.json masque-bati/manifeste.json propriete-toits-v1/manifeste.json
                  ambiances/hiver-actuelle.json])
    assert_equal %w[hiver], t.disponibles[:ambiances]
  end

  test "sans le lot, rien n'est disponible" do
    assert_equal({ vrai: false, styles: [], blanche: false, ambiances: [], arbres: false, lumieres: false },
                 tuiles(%w[masque-bati/manifeste.json masque-arbres/manifeste.json]).disponibles)
  end

  test "masque des arbres et lampadaires : facultatifs, sondés sur leur manifeste" do
    t = tuiles(%w[toits-v1/manifeste.json masque-arbres/manifeste.json lampadaires-bdtopo/manifeste.json])
    assert t.disponibles[:arbres]
    assert t.disponibles[:lumieres]
    assert_equal %w[masque-arbres lampadaires-bdtopo/lampadaires-bdtopo.json], t.pour_js.values_at(:arbres, :lumieres)
    assert_nil tuiles(%w[toits-v1/manifeste.json]).pour_js[:lumieres]
  end

  test "les lanternes relevées passent avant les lampadaires BD TOPO" do
    t = tuiles(%w[toits-v1/manifeste.json lampadaires-bdtopo/manifeste.json lumieres-nuit/manifeste.json])
    assert_equal "lumieres-nuit/lanternes.json", t.pour_js[:lumieres]
  end

  test "la base vient de DIORAMA_TILES_URL, sinon du domaine par défaut" do
    assert_equal DioramaTuiles::URL_DEFAUT, DioramaTuiles.new(sonde: ->(_) { false }).base unless ENV["DIORAMA_TILES_URL"].present?
    assert_equal "https://ailleurs.test", DioramaTuiles.new(base: "https://ailleurs.test/", sonde: ->(_) { false }).base
  end
end
