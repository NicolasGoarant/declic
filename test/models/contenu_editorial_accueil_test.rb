require "test_helper"

# Contenu éditorial de la home : config/temoignages.yml (bloc simple, sans modèle) et PassagePresse.
class ContenuEditorialAccueilTest < ActiveSupport::TestCase
  TEMOIGNAGES = YAML.safe_load_file(Rails.root.join("config/temoignages.yml"), symbolize_names: true)

  test "chaque témoignage est complet et sa photo existe dans avatars" do
    assert TEMOIGNAGES.any?
    TEMOIGNAGES.each do |t|
      %i[prenom profession ville citation photo].each { |cle| assert t[cle].present?, "#{t[:prenom]} : #{cle}" }
      assert_includes [ true, false ], t[:placeholder]
      assert t[:photo].start_with?("avatars/"), t[:photo]
      assert Rails.root.join("app/assets/images", t[:photo]).exist?, t[:photo]
    end
  end

  test "les entrées de démonstration de presse sont masquées en production" do
    assert PassagePresse.visibles(production: true).none?(&:placeholder)
  end

  test "chaque citation de presse réelle pointe vers sa source" do
    PassagePresse::TOUS.reject(&:placeholder).each do |passage|
      assert_match %r{\Ahttps://}, passage.url, passage.media
    end
  end

  test "les logos de presse existent" do
    PassagePresse::TOUS.map(&:logo).each do |fichier|
      assert Rails.root.join("app/assets/images", fichier).exist?, fichier
    end
  end
end
