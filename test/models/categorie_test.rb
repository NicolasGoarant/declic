require "test_helper"

class CategorieTest < ActiveSupport::TestCase
  test "les catégories d'opportunité sont exactement celles du modèle, plus les Belles Histoires" do
    assert_equal Opportunity::CATEGORIES.sort, (Categorie::TOUTES.map(&:cle) - [ Categorie::HISTOIRES ]).sort
    assert_equal 7, Categorie::TOUTES.size
    assert_equal %w[ecologiser entreprendre formation benevolat pratiquer decouvrir], Opportunity::CATEGORIES
  end

  test "trouver ignore la casse et rend nil pour une clé inconnue" do
    assert_equal "Se former", Categorie.trouver("FORMATION").libelle
    assert_nil Categorie.trouver("autre")
  end
end
