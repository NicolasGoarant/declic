require "test_helper"
require "minitest/mock"

# config/diorama/occupations_places.yml : le fichier réel est valide, et chaque faute de saisie est nommée.
class DioramaOccupationsTest < ActiveSupport::TestCase
  def lire(yaml)
    fichier = Tempfile.new([ "occupations", ".yml" ])
    fichier.write(yaml)
    fichier.close
    DioramaOccupations.new(fichier.path).installations
  ensure
    fichier&.unlink
  end

  SPRITES = <<~YAML.freeze
    sprites:
      sapin: { image: diorama/occupations/sapin.png, ancre_px: [72, 215], px_par_pixel_mosaique: 4 }
  YAML

  def installation(**champs)
    base = { "id" => "essai", "nom" => "Essai", "place" => "Place", "debut" => "2026-11-20", "fin" => "2027-01-03",
             "position" => { "lat" => 48.69, "lon" => 6.18 }, "sprite" => "sapin", "zooms" => [ 6, 7 ] }
    SPRITES + { "installations" => [ base.merge(champs.transform_keys(&:to_s)) ] }.to_yaml.delete_prefix("---\n")
  end

  test "le fichier réel est valide : quatre installations, images présentes, dates ordonnées" do
    toutes = DioramaOccupations.new.installations
    assert_equal %w[sapin-stanislas-2026 grande-roue-carriere-2026 patinoire-carriere-2026 marche-noel-charles-iii-2026],
                 toutes.map { |o| o[:id] }
    toutes.each do |o|
      assert_operator o[:debut], :<=, o[:fin]
      assert_match %r{\A/assets/diorama/occupations/}, o[:image]
      assert_equal 2, o[:ancre].size
      assert_operator o[:k], :>, 0
    end
    assert_equal "2026-11-20", toutes.find { |o| o[:id] == "grande-roue-carriere-2026" }[:debut]
  end

  test "pour_js passe par les tuiles" do
    assert_equal DioramaOccupations.pour_js, DioramaTuiles.new(sonde: ->(_) { false }).pour_js[:occupations]
  end

  test "une installation valide sort avec les données du sprite" do
    o = lire(installation).first
    assert_equal({ debut: "2026-11-20", fin: "2027-01-03", zooms: [ 6, 7 ], ancre: [ 72.0, 215.0 ], k: 4.0 },
                 o.slice(:debut, :fin, :zooms, :ancre, :k))
    assert_nil o[:lumieres]
  end

  test "les fautes de saisie sont nommées" do
    {
      installation(fin: "2026-11-01") => /fin .* avant début/,
      installation(debut: "20/11/2026") => /debut illisible/,
      installation(sprite: "inconnu") => /sprite inconnu/,
      installation(zooms: [ 12 ]) => /zooms hors de 0..9/,
      installation(position: { "lat" => 6.18, "lon" => 48.69 }) => /hors de la Métropole/,
      installation(nom: nil) => /champs manquants nom/
    }.each do |yaml, message|
      assert_raises(DioramaOccupations::Invalide, message.source) { lire(yaml) }.then { |e| assert_match message, e.message }
    end
  end

  test "deux installations au même identifiant sont refusées" do
    yaml = installation
    double = YAML.safe_load(yaml)
    double["installations"] << double["installations"].first.deep_dup
    erreur = assert_raises(DioramaOccupations::Invalide) { lire(double.to_yaml) }
    assert_match(/en double/, erreur.message)
  end

  test "une image absente est refusée" do
    yaml = installation.sub("sapin.png", "absente.png")
    assert_match(/image absente/, assert_raises(DioramaOccupations::Invalide) { lire(yaml) }.message)
  end

  test "un fichier fautif ne casse pas la page : pour_js rend une liste vide" do
    DioramaOccupations.stub(:toutes, -> { raise DioramaOccupations::Invalide, "essai" }) do
      assert_equal [], DioramaOccupations.pour_js
    end
  end
end
