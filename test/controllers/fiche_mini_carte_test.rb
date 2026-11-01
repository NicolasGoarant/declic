require "test_helper"

# La mini-carte d'une fiche publiée pose son pin avec le contrôleur `diorama`, dont `iconePin` exige
# le gabarit complet (.pin-vol, .pin-picto, tige, socle) : sans lui, le pin plante et la carte reste vide.
class FicheMiniCarteTest < ActionDispatch::IntegrationTest
  test "la fiche géocodée embarque un gabarit de pin complet pour la mini-carte" do
    fiche = opportunities(:one)
    fiche.update_columns(is_active: true, latitude: 48.69366, longitude: 6.1819, category: "rencontres", title: "Visite du musée")

    get opportunity_path(fiche)
    assert_response :success
    assert_select "[data-controller~=diorama][data-diorama-mini-value=true]" do
      assert_select "template[data-diorama-target=modelePin] .pin .pin-vol img.pin-picto"
      assert_select "template[data-diorama-target=modelePin] .pin-tige"
      assert_select "template[data-diorama-target=modelePin] .pin-socle"
    end
  end
end
