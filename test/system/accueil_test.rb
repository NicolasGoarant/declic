require "application_system_test_case"
require "minitest/mock"

# L'écran Carte de /labo/accueil, au format mobile (la tab bar et la bottom sheet n'existent pas
# sur bureau). Les tuiles sont déclarées absentes : ni carte ni CDN, seul l'écran est éprouvé.
class AccueilTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(390, 844)
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
  end

  def sur_l_ecran_carte(&bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit root_path
      bloc.call
    end
  end

  test "la bottom sheet est repliée au chargement puis s'ouvre au clic sur la poignée" do
    sur_l_ecran_carte do
      assert_selector ".acc-poignee[aria-expanded='false']"
      assert_no_selector ".acc-volet--ouvert"
      assert_equal "acc-volet-panneau", find(".acc-poignee")["aria-controls"]

      find(".acc-poignee").click

      assert_selector ".acc-poignee[aria-expanded='true']"
      assert_selector ".acc-volet--ouvert"

      find("body").send_keys(:escape)
      assert_selector ".acc-poignee[aria-expanded='false']"
    end
  end

  test "la tab bar a cinq emplacements, le « + » Proposer en troisième position" do
    sur_l_ecran_carte do
      onglets = all(".acc-onglets > *")
      assert_equal 5, onglets.size
      assert_equal [ "Carte", "Opportunités", "Proposer", "Belles Histoires", "Déclic ?" ], onglets.map { |o| o.text.strip }

      plus = onglets[2]
      assert_includes plus[:class], "acc-onglet-plus"
      assert_equal "Proposer", plus["aria-label"]
      assert_equal new_opportunity_path, URI(plus[:href]).path
      assert_equal "page", onglets[0]["aria-current"]
    end
  end

  test "la recherche du header filtre la liste « Au centre de la vue » sans tenir compte des accents" do
    sur_l_ecran_carte do
      find(".acc-recherche input").click
      assert_selector ".acc-poignee[aria-expanded='true']"
      find(".acc-recherche input").set("zzzzzz")
      assert_selector "[data-diorama-target='vide']", text: "Aucun résultat pour « zzzzzz »"
      assert_selector "[data-diorama-target='poigneeTitre']", visible: :all, text: "Résultats"
      find(".acc-recherche input").set("")
      assert_no_selector "[data-diorama-target='poigneeTitre']", visible: :all, text: "Résultats"
    end
  end

  test "l'écran Carte ne garde que le logo, la légende des six catégories en bas et le zoom" do
    sur_l_ecran_carte do
      %w[.acc-puces .acc-territoire .acc-filtres .acc-rond .acc-entete-actions].each { |css| assert_no_selector css }
      assert_selector ".acc-entete .acc-recherche input[type=search]"
      assert_no_selector "[aria-label='Recentrer la carte']"
      assert_selector "[aria-label='Zoomer']"
      assert_selector "[aria-label='Dézoomer']"
      assert_selector ".acc-entete .acc-logo", text: "Déclic"

      # La légende est dans le volet, juste au-dessus de sa poignée, et reste utilisable volet replié.
      assert_selector ".acc-volet > .acc-categories + .acc-poignee"
      legende = find(".acc-categories").rect
      assert_operator legende.y + legende.height, :<=, find(".acc-poignee").rect.y

      categories = all(".acc-cat").map { |c| c.find(".acc-cat-libelle").text }
      assert_equal 6, categories.size
      assert_equal "Belles Histoires", categories.last

      find(".acc-cat[data-cle='histoires']").click
      assert_selector ".acc-cat[data-cle='histoires'][aria-pressed='true']"
    end
  end
end
