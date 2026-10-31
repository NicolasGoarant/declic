require "application_system_test_case"
require "minitest/mock"

# La bascule publique des familles masquées, sur la grille de /labo/opportunites : les tuiles sont
# déclarées absentes, seul le filtrage est éprouvé (Brocantes masquées par défaut, choix mémorisé).
class FamillesCarteTest < ApplicationSystemTestCase
  setup do
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
    { "Vide-grenier du quartier" => "petite_manifestation", "Conférence sur le climat" => "decouvrir", "Atelier vélo" => "pratiquer" }.each do |titre, famille|
      Opportunity.create!(title: titre, description: "Texte.", category: "rencontres", latitude: 48.69, longitude: 6.18,
                          famille: famille, is_active: true)
    end
  end

  test "les familles masquées n'apparaissent qu'à la demande du visiteur, qui retrouve son choix" do
    DioramaTuiles.stub(:new, @tuiles) do
      visit labo_opportunites_path
      assert_text "Atelier vélo"
      assert_no_text "Vide-grenier du quartier"
      assert_no_text "Conférence sur le climat"

      click_button "Brocantes, foires et fêtes"
      assert_text "Vide-grenier du quartier"
      assert_no_text "Conférence sur le climat"
      assert_selector ".bascule-famille[aria-pressed='true']", count: 1

      visit labo_opportunites_path
      assert_text "Vide-grenier du quartier"

      click_button "Brocantes, foires et fêtes"
      assert_no_text "Vide-grenier du quartier"
    end
  end
end
