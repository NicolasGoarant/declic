require "test_helper"

class Veille::EtiquetageTest < ActiveSupport::TestCase
  test "le jeu compte 30 cas distincts, chacun avec une décision de la v4" do
    cas = Veille::Etiquetage.cas
    assert_equal 30, cas.map(&:ref).uniq.size
    assert cas.all? { |c| %w[Gardé Écarté].include?(c.v4["decision"]) && c.titre.present? && c.lien.present? }
  end

  test "aucun contenu de presse dans le jeu : ni chapeau ni motif tiré du chapeau" do
    presse = Veille::Etiquetage.cas.select { |c| c.lien.match?(/estrepublicain|lagazettefrance/) }
    assert_equal 8, presse.size
    assert presse.all? { |c| c.presse && c.texte.nil? && c.quand.empty? && c.v4["motif"].nil? }
    assert Veille::Etiquetage.cas.reject(&:presse).all? { |c| c.texte.present? }
  end

  test "la comparaison compte les accords, sans les douteux" do
    garde = Veille::Etiquetage.cas.find { |c| c.v4["decision"] == "Gardé" }
    ecarte = Veille::Etiquetage.cas.find { |c| c.v4["decision"] == "Écarté" }
    autre = Veille::Etiquetage.cas.find { |c| c.v4["decision"] == "Gardé" && c != garde }
    Veille::Etiquette.create!(ref: garde.ref, avis: "garder")
    Veille::Etiquette.create!(ref: ecarte.ref, avis: "garder")
    Veille::Etiquette.create!(ref: autre.ref, avis: "douteux")

    c = Veille::Etiquetage.comparaison
    assert_equal [3, 27, 1, 2], [c.etiquetes, c.reste, c.accords, c.comparables]
  end
end
