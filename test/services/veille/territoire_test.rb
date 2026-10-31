require "test_helper"

class Veille::TerritoireTest < ActiveSupport::TestCase
  T = Veille::Territoire

  test "reconnaît les communes du Grand Est, sans casse ni accents" do
    assert_equal "Saint-Dié-des-Vosges", T.canonique("SAINT DIE DES VOSGES")
    assert_equal "Vandœuvre-lès-Nancy", T.canonique("vandoeuvre")
    assert_nil T.canonique("Besançon")
  end

  test "la Meurthe-et-Moselle comprend le Grand Nancy et Toul, pas Metz" do
    assert T.meurthe_et_moselle?("Laxou")
    assert T.meurthe_et_moselle?("Pont-à-Mousson")
    assert_not T.meurthe_et_moselle?("Metz")
    assert_not T.meurthe_et_moselle?("")
  end

  test "une opportunité doit être en Meurthe-et-Moselle, une histoire dans le Grand Est" do
    assert T.admis?("Toul", "opportunite")
    assert_not T.admis?("Strasbourg", "opportunite")
    assert T.admis?("Strasbourg", "belle_histoire")
    assert T.admis?("Strasbourg", nil)
    assert_not T.admis?("Besançon", "belle_histoire")
  end

  test "repère la première commune citée, le nom le plus long d'abord" do
    assert_equal "Pont-à-Mousson", T.trouver_dans("Un atelier à Pont-à-Mousson puis à Nancy")
    assert_equal "Villers-lès-Nancy", T.trouver_dans("Rencontre à Villers-lès-Nancy")
    assert_equal "Nancy", T.trouver_dans("Dans le Grand Nancy")
  end

  test "ne prend ni les mots courants ni les noms sans majuscule" do
    assert_nil T.trouver_dans("Son salon a ouvert. Salon du livre. Grand bonheur.")
    assert_nil T.trouver_dans("elle part de toul")
    assert_nil T.trouver_dans("Le chemin de sa vie")
    assert_nil T.trouver_dans("Une quête à Dampierre-sur-Salon")
    assert_nil T.trouver_dans("Le dispositif Nancyen de mobilité")
    assert_nil T.trouver_dans("")
    assert_nil T.trouver_dans(nil)
  end

  test "une commune ambiguë reste reconnue si la source la donne" do
    assert_equal "Salon", T.canonique("Salon")
  end
end
