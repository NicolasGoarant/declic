require "application_system_test_case"
require "minitest/mock"

# La pastille « +n » des bouquets de la carte (diorama_controller#bouquet, #ouvrirGrappe) : un vrai bouton,
# qui cadre le groupe si un zoom plus fort le sépare, et liste les fiches dans une bulle sinon (même lieu).
class GrappesTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(1280, 900)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
    base = { description: "Une initiative.", is_active: true, location: "Nancy", category: "ecologie" }
    # Neuf fiches exactement au même point (place Stanislas) : aucune échelle ne les sépare.
    9.times { |i| Opportunity.create!(base.merge(title: "Même lieu #{i + 1}", latitude: 48.6936, longitude: 6.1833)) }
    # Huit fiches à quelques dizaines de mètres : groupées à l'échelle de la vue, séparées au zoom maximal.
    8.times { |i| Opportunity.create!(base.merge(title: "Voisine #{i + 1}", latitude: 48.7000 + (i % 3) * 0.0004, longitude: 6.1900 + (i / 3) * 0.0006)) }
  end

  def sur_la_carte(&bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit root_path
      assert_selector "[data-controller~=diorama][data-fond=diorama]"
      assert_selector ".bouquet-plus", minimum: 2, wait: 10
      bloc.call
    end
  end

  def zoom = evaluate_script("#{CONTROLEUR}.carte.getZoom()")

  test "la pastille est un bouton focalisable, libellé, qui annonce les fiches cachées" do
    sur_la_carte do
      plus = find(".bouquet-plus", text: "+3")
      assert_equal "button", plus.tag_name
      assert_equal "Voir les 3 autres opportunités", plus[:"aria-label"]
      assert_equal "Voir les 3 autres opportunités", plus[:title]
      assert_equal "9", plus["data-grappe"]
    end
  end

  test "un groupe au même point ne se sépare pas : le clic liste toutes ses fiches, sans zoomer" do
    sur_la_carte do
      avant = zoom
      find(".bouquet-plus", text: "+3").click
      assert_selector ".grappe[data-grappe-liste='9'] .grappe-ligne", count: 9
      assert_text "9 opportunités ici"
      assert_equal avant, zoom
      assert first(".grappe-ligne")[:href].end_with?("/opportunities/#{Opportunity.find_by(title: 'Même lieu 1').slug}")
      find("body").send_keys(:escape)
      assert_no_selector ".grappe"
    end
  end

  test "un groupe séparable : le clic cadre la caméra dessus et le zoom augmente" do
    sur_la_carte do
      avant = zoom
      # Clic envoyé par le script : selon la vue, le groupe peut passer sous l'en-tête de la page.
      assert_selector ".bouquet-plus", text: "+2"
      execute_script('[...document.querySelectorAll(".bouquet-plus")].find((e) => e.textContent === "+2").click()')
      assert_no_selector ".grappe"
      # Le cadrage est animé : on attend sa fin.
      page.document.synchronize(10) { raise Capybara::ExpectationNotMet, "zoom inchangé (#{avant})" unless zoom > avant }
    end
  end

  test "au clavier, Entrée sur la pastille agit comme le clic" do
    sur_la_carte do
      find(".bouquet-plus", text: "+3").send_keys(:enter)
      assert_selector ".grappe .grappe-ligne", count: 9
    end
  end
end
