require "test_helper"

class LaboHelperTest < ActionView::TestCase
  include AccueilHelper
  include LaboHelper

  test "categories_reelles exclut la pseudo-catégorie histoires" do
    cles = categories_reelles.map(&:cle)
    assert_equal Opportunity::CATEGORIES.sort, cles.sort
    assert_not_includes cles, Categorie::HISTOIRES
  end

  test "opportunite_pour_carte porte les champs de la carte et du pin, coordonnées en nombres" do
    o = Opportunity.new(
      id: 42, title: "Repair Café", category: "ecologiser", description: "Un texte assez long. " * 5,
      city: "Nancy", location: "12 rue X, 54000 Nancy", latitude: 48.69, longitude: 6.18,
      starts_on: Date.new(2026, 3, 14), created_at: Time.zone.now
    )
    point = opportunite_pour_carte(o)

    assert_equal "o42", point[:id]
    assert_equal "ecologiser", point[:categorie]
    assert_equal "Écologiser", point[:categorie_libelle]
    assert_kind_of Float, point[:latitude]
    assert_kind_of Float, point[:longitude]
    assert_equal "Nancy", point[:commune]
    assert point[:extrait].length <= 141 # truncate(140) + « … »
  end

  test "opportunite_pour_carte : sans dates, l'horaire affiché retombe sur « Ouvert toute l'année »" do
    o = Opportunity.new(id: 1, title: "Accueil permanent", category: "benevolat", description: "d",
                         latitude: 48.69, longitude: 6.18, created_at: Time.zone.now)
    assert_equal "Ouvert toute l'année", opportunite_pour_carte(o)[:date_affichee]
  end

  test "histoire_pour_carte porte toujours icone_categorie=histoires (étincelle sur le pin), même filtrée par thématique" do
    s = Story.new(id: 7, title: "Le déclic de Camille", thematique: "ecologiser", quote: "J'ai osé.",
                   city: "Nancy", location: "Nancy", latitude: 48.69, longitude: 6.18,
                   source_published_on: Date.new(2026, 2, 1), created_at: Time.zone.now)
    point = histoire_pour_carte(s)

    assert_equal "s7", point[:id]
    assert_equal "ecologiser", point[:categorie] # sert au filtre par thématique et à la carte
    assert_equal Categorie::HISTOIRES, point[:icone_categorie] # sert uniquement au pictogramme du pin
    assert_equal "J'ai osé.", point[:citation]
    assert_equal "Février 2026", point[:date_affichee]
  end

  test "mois_annee formate en français, ou nil sans date" do
    assert_equal "Août 2026", mois_annee(Date.new(2026, 8, 3))
    assert_nil mois_annee(nil)
  end
end
