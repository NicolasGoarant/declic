require "test_helper"
require_relative "support"

class Veille::XlsxImporterTest < ActiveSupport::TestCase
  include VeilleSupport

  FICHIER = Rails.root.join("test/fixtures/files/reperage_test.xlsx")

  test "importe les deux onglets au statut « à vérifier », sans toucher aux autres" do
    bilan = Veille::XlsxImporter.new(FICHIER).call

    assert_equal ["Opportunités", "Belles Histoires - pistes"], bilan.onglets
    assert_equal 3, bilan.crees
    assert_equal 1, bilan.ignores, "la ligne sans lien n'est pas devinée"

    velos = Veille::Candidate.find_by!(url: "https://exemple.fr/velos")
    assert_equal "a_verifier", velos.status
    assert_equal "opportunite", velos.item_type
    assert_equal "ecologiser", velos.declic_category
    assert_equal "Vandœuvre-lès-Nancy", velos.commune
    assert_equal Date.new(2027, 2, 14), velos.starts_on
    assert_equal "import_xlsx", velos.origin

    scolaire = Veille::Candidate.find_by!(url: "https://exemple.fr/scolaire")
    assert_equal "benevolat", scolaire.declic_category
    assert_equal "Toute l'année", scolaire.schedule_text, "un texte libre devient le régime"
    assert_nil scolaire.starts_on

    histoire = Veille::Candidate.find_by!(url: "https://exemple.fr/couturiere")
    assert_equal "belle_histoire", histoire.item_type
    assert_equal "Laxou", histoire.commune

    assert_nil Veille::Candidate.find_by(url: "https://exemple.fr/x"), "onglet inconnu ignoré"
  end

  test "ne passe pas par l'IA : ils attendent la relecture, pas l'enrichissement" do
    Veille::XlsxImporter.new(FICHIER).call
    assert_equal 0, Veille::Candidate.a_enrichir.where(origin: "import_xlsx").count
  end

  test "un second import ne crée aucun doublon" do
    Veille::XlsxImporter.new(FICHIER).call
    bilan = Veille::XlsxImporter.new(FICHIER).call
    assert_equal 0, bilan.crees
    assert_equal 3, bilan.doublons
  end
end
