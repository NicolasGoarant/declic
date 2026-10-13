require "test_helper"

class Veille::GrandNancyTest < ActiveSupport::TestCase
  test "reconnaît une commune sans égard à la casse, aux accents ni aux tirets" do
    assert_equal "Vandœuvre-lès-Nancy", Veille::GrandNancy.canonique("VANDOEUVRE LES NANCY")
    assert_equal "Villers-lès-Nancy", Veille::GrandNancy.canonique("villers")
    assert_equal "Nancy", Veille::GrandNancy.canonique("Ville de Nancy")
  end

  test "refuse les communes voisines hors métropole" do
    assert_not Veille::GrandNancy.inclut?("Toul")
    assert_not Veille::GrandNancy.inclut?("Pont-à-Mousson")
    assert_not Veille::GrandNancy.inclut?("")
  end

  test "trouve la commune citée dans un texte, la plus longue d'abord" do
    assert_equal "Villers-lès-Nancy", Veille::GrandNancy.trouver_dans("Equasens dévoile sa feuille de route à Villers-lès-Nancy")
    assert_equal "Laxou", Veille::GrandNancy.trouver_dans("Rencontre à Laxou, près de Toul")
    assert_nil Veille::GrandNancy.trouver_dans("Rien à Metz ni à Épinal")
  end

  test "ne confond pas un mot qui contient un nom de commune" do
    assert_nil Veille::GrandNancy.trouver_dans("Le dispositif Nancyen de mobilité")
  end
end
