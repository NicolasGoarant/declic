require "test_helper"

class DioramaTuilesTest < ActiveSupport::TestCase
  # Une base différente par test : le cache de sonde est indexé par base.
  def tuiles(presentes)
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    DioramaTuiles.new(base: base, sonde: ->(url) { presentes.any? { |p| url == "#{base}/#{p}" } })
  end

  test "seul le lot toits-v1 : pas de maquette blanche ni d'ambiance" do
    assert_equal({ vrai: true, styles: %w[toits-v1], blanche: false, ambiances: [], arbres: false, lumieres: false, mobiles: false, vivants: false, nuit: false, trains: false },
                 tuiles([ "toits-v1/manifeste.json" ]).disponibles)
  end

  test "les deux styles publiés sont listés, jeu-video-v2 en tête" do
    t = tuiles(%w[toits-v1/manifeste.json jeu-video-v2/manifeste.json])
    assert_equal %w[jeu-video-v2 toits-v1], t.disponibles[:styles]
    assert_equal %w[jeu-video-v2 toits-v1], t.pour_js[:styles]
    assert_equal "jeu-video-v2", t.pour_js[:style_defaut]
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
    assert_equal({ vrai: false, styles: [], blanche: false, ambiances: [], arbres: false, lumieres: false, mobiles: false, vivants: false, nuit: false, trains: false },
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

  test "les bateaux demandent leur manifeste ET la carte de propriété, qui les masque" do
    refute tuiles(%w[toits-v1/manifeste.json mobiles-v6/manifeste.json]).disponibles[:mobiles]
    t = tuiles(%w[toits-v1/manifeste.json propriete-toits-v1/manifeste.json mobiles-v6/manifeste.json])
    assert t.disponibles[:mobiles]
    assert_equal "#{t.base}/mobiles-v6", t.pour_js[:mobiles]
  end

  test "DIORAMA_MOBILES_URL fait lire les bateaux ailleurs que sur R2" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    present = [ "#{base}/toits-v1/manifeste.json", "#{base}/propriete-toits-v1/manifeste.json", "http://localhost:8766/mobiles-v1/manifeste.json" ]
    t = DioramaTuiles.new(base: base, mobiles: "http://localhost:8766/mobiles-v1/", sonde: ->(url) { present.include?(url) })
    assert t.disponibles[:mobiles]
    assert_equal "http://localhost:8766/mobiles-v1", t.pour_js[:mobiles]
  end

  test "les vivants ne sont disponibles qu'avec un style, la carte de propriété et leur manifeste" do
    refute tuiles(%w[toits-v1/manifeste.json vivants-v2/manifeste.json]).disponibles[:vivants]
    t = tuiles(%w[toits-v1/manifeste.json propriete-toits-v1/manifeste.json vivants-v2/manifeste.json])
    assert t.disponibles[:vivants]
    assert_equal "#{t.base}/vivants-v2", t.pour_js[:vivants]
  end

  test "les trains exigent un style, la carte de propriété et leur manifeste, sous la base ou à DIORAMA_TRAINS_URL" do
    refute tuiles(%w[toits-v1/manifeste.json trains-v1/manifeste.json]).disponibles[:trains]
    t = tuiles(%w[toits-v1/manifeste.json propriete-toits-v1/manifeste.json trains-v1/manifeste.json])
    assert t.disponibles[:trains]
    assert_equal "#{t.base}/trains-v1", t.pour_js[:trains]
    refute tuiles(%w[toits-v1/manifeste.json propriete-toits-v1/manifeste.json]).disponibles[:trains]
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    assert_equal "http://localhost:8778", DioramaTuiles.new(base: base, trains: "http://localhost:8778/", sonde: ->(_) { false }).trains
  end

  test "une surcouche n'est annoncée au navigateur que si son manifeste répond" do
    assert_empty tuiles(%w[jeu-video-v2/manifeste.json]).pour_js[:surcouches]
    t = tuiles(%w[jeu-video-v2/manifeste.json jeu-video-v2-coupes1/manifeste.json])
    assert_equal({ "jeu-video-v2" => "jeu-video-v2-coupes1" }, t.pour_js[:surcouches])
    assert_equal %w[jeu-video-v2], t.disponibles[:styles]
  end

  test "les vivants se lisent dans vivants-v2 sous la base, ou à DIORAMA_VIVANTS_URL" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    assert_equal "#{base}/vivants-v2", DioramaTuiles.new(base: base, vivants: nil, sonde: ->(_) { false }).vivants
    assert_equal "http://localhost:8777", DioramaTuiles.new(base: base, vivants: "http://localhost:8777/", sonde: ->(_) { false }).vivants
  end

  test "la nuit chaude n'est disponible qu'avec un style et son manifeste, sous la base ou à DIORAMA_NUIT_URL" do
    refute tuiles(%w[nuit-chaude-v1/manifeste.json]).disponibles[:nuit]
    t = tuiles(%w[toits-v1/manifeste.json nuit-chaude-v1/manifeste.json])
    assert t.disponibles[:nuit]
    assert_equal "#{t.base}/nuit-chaude-v1", t.pour_js[:nuit]
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    present = [ "#{base}/toits-v1/manifeste.json", "http://localhost:8790/nuit-chaude-v1/manifeste.json" ]
    t = DioramaTuiles.new(base: base, nuit: "http://localhost:8790/nuit-chaude-v1/", sonde: ->(url) { present.include?(url) })
    assert t.disponibles[:nuit]
    assert_equal "http://localhost:8790/nuit-chaude-v1", t.pour_js[:nuit]
  end

  test "la base vient de DIORAMA_TILES_URL, sinon du domaine par défaut" do
    assert_equal DioramaTuiles::URL_DEFAUT, DioramaTuiles.new(sonde: ->(_) { false }).base unless ENV["DIORAMA_TILES_URL"].present?
    assert_equal "https://ailleurs.test", DioramaTuiles.new(base: "https://ailleurs.test/", sonde: ->(_) { false }).base
  end
end
