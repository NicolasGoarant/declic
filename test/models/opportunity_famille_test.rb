require "test_helper"

class OpportunityFamilleTest < ActiveSupport::TestCase
  def fiche(famille)
    Opportunity.create!(title: "Fiche #{SecureRandom.hex(3)}", description: "Texte.", category: "decouvrir",
                        latitude: 48.69, longitude: 6.18, famille: famille, is_active: true)
  end

  test "les familles masquées (bascules « Afficher aussi ») se rattachent toutes à Découvrir" do
    Opportunity::FAMILLES_MASQUEES.each { |famille| assert_equal "decouvrir", Veille::AiEnricher::CATEGORIE_PAR_FAMILLE.fetch(famille) }
  end

  test "l'ancienne catégorie n'est plus acceptée" do
    assert_not Opportunity.new(title: "T", description: "D", category: "rencontres").valid?
  end

  test "sans_familles_masquees retire les brocantes, garde le reste (conférences et visites comprises) et les fiches sans famille" do
    gardees = [fiche(nil), fiche("pratiquer"), fiche("decouvrir")]
    masquees = [fiche("petite_manifestation")]
    resultat = Opportunity.sans_familles_masquees
    gardees.each { |o| assert_includes resultat, o }
    masquees.each { |o| assert_not_includes resultat, o }
  end

  test "une fiche masquée reste active" do
    assert_includes Opportunity.active, fiche("petite_manifestation")
  end

  test "famille_masquable ne vaut que pour les familles masquées" do
    assert_equal "petite_manifestation", fiche("petite_manifestation").famille_masquable
    assert_nil fiche("decouvrir").famille_masquable
    assert_nil fiche("pratiquer").famille_masquable
    assert_nil fiche(nil).famille_masquable
  end

  test "une famille vide devient nulle, une famille inconnue est refusée" do
    assert_nil fiche("").famille
    assert_not Opportunity.new(title: "T", description: "D", category: "decouvrir", famille: "inconnue").valid?
  end
end
