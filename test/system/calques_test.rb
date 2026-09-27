require "application_system_test_case"
require "minitest/mock"

# Le panneau « Calques » de /labo/accueil : bascule Diorama / Plan, filtres dans les deux fonds,
# choix gardé sur l'appareil. Le diorama est servi par TuilesFactices ; le plan tire ses tuiles
# d'OpenStreetMap et Leaflet du CDN, comme en vrai.
class CalquesTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(1280, 900)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
    base = { description: "Une initiative.", is_active: true, location: "Nancy" }
    Opportunity.create!(base.merge(title: "Jardin partagé", category: "ecologiser", latitude: 48.6936, longitude: 6.1833))
    Opportunity.create!(base.merge(title: "Maraude", category: "benevolat", latitude: 48.6975, longitude: 6.1844))
    Opportunity.create!(base.merge(title: "Atelier à Pont-à-Mousson", category: "formation", latitude: 48.905, longitude: 6.054))
  end

  def sur_la_carte(&bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit labo_accueil_path
      assert_selector "[data-controller~=diorama][data-fond]"
      bloc.call
    end
  end

  def vue = evaluate_script("(() => { const v = #{CONTROLEUR}.vueGeo(); return [v.lat, v.lon, v.zoomPlan] })()")

  # Les catégories des marqueurs à l'écran (pins isolés et fleurs des bouquets).
  def categories_affichees
    evaluate_script(<<~JS).sort
      (() => {
        const c = #{CONTROLEUR}
        const ids = [...document.querySelectorAll(".acc-pin .pin[data-id], .bouquet-fleur[data-id]")].map((el) => el.dataset.id)
        return [...new Set(ids)].map((id) => c.points.find((p) => p.id === id).categorie)
      })()
    JS
  end

  def choisir_fond(libelle)
    find(".acc-rond-calques").click
    within("#acc-calques") { find("label.acc-calques-option", text: libelle).click }
    find("body").send_keys(:escape)
    assert_no_selector "#acc-calques", visible: true
  end

  test "la bascule Diorama / Plan garde le centre et une échelle voisine, et revient" do
    sur_la_carte do
      assert_selector "[data-fond=diorama]"
      lat, lon, zoom = vue

      choisir_fond "Plan"

      assert_selector "[data-fond=plan]"
      assert_selector ".leaflet-tile-pane img[src*='tile.openstreetmap.org']", visible: :all
      lat2, lon2, zoom2 = vue
      assert_in_delta lat, lat2, 0.0005
      assert_in_delta lon, lon2, 0.0005
      assert_in_delta zoom, zoom2, 0.6

      choisir_fond "Diorama"

      assert_selector "[data-fond=diorama]"
      lat3, lon3, = vue
      assert_in_delta lat, lat3, 0.001
      assert_in_delta lon, lon3, 0.001
    end
  end

  test "le plan montre aussi les initiatives hors de la Métropole" do
    sur_la_carte do
      assert_equal 2, evaluate_script("#{CONTROLEUR}.poses.length")
      choisir_fond "Plan"
      assert_selector "[data-fond=plan]"
      assert_equal 3, evaluate_script("#{CONTROLEUR}.poses.length")
      assert_selector "[data-cle=formation] [data-compte]", text: "1"
    end
  end

  test "un filtre de catégorie reste actif d'un fond à l'autre" do
    sur_la_carte do
      assert_equal %w[benevolat ecologiser], categories_affichees
      find(".acc-cat[data-cle=ecologiser]").click
      assert_selector ".acc-cat[data-cle=ecologiser][aria-pressed=true]"
      assert_equal %w[ecologiser], categories_affichees
      assert_selector "[data-diorama-target=compteur]", text: "1 lieu", visible: :all

      choisir_fond "Plan"

      assert_selector "[data-fond=plan]"
      assert_selector ".acc-cat[data-cle=ecologiser][aria-pressed=true]"
      assert_equal %w[ecologiser], categories_affichees
      assert_selector ".acc-fiches .fiche", count: 1
      assert_selector ".acc-fiches .fiche", text: "Jardin partagé"
    end
  end

  test "le fond choisi est gardé sur l'appareil et repris au retour" do
    sur_la_carte do
      choisir_fond "Plan"
      assert_equal "plan", evaluate_script("localStorage.getItem('declic:fond')")

      visit labo_accueil_path

      assert_selector "[data-fond=plan]"
      find(".acc-rond-calques").click
      assert find("input[name=calques-fond][value=plan]", visible: :all).checked?
    end
  end

  test "le style du diorama (Jeu vidéo par défaut) se garde et ne recharge pas la carte" do
    sur_la_carte do
      assert_equal "jeu-video-v1", evaluate_script("#{CONTROLEUR}.style")
      assert_selector ".leaflet-tile-pane img[src*='/jeu-video-v1/']", visible: :all
      lat, lon, = vue

      find(".acc-rond-calques").click
      within("#acc-calques") { find("label.acc-calques-option", text: "Réaliste").click }

      assert_equal "toits-v1", evaluate_script("#{CONTROLEUR}.style")
      assert_selector ".leaflet-tile-pane img[src*='/toits-v1/']", visible: :all
      assert_equal "toits-v1", evaluate_script("localStorage.getItem('declic:style')")
      lat2, lon2, = vue
      assert_in_delta lat, lat2, 0.0001 # même carte : la vue n'a pas bougé
      assert_in_delta lon, lon2, 0.0001
      find("body").send_keys(:escape)

      visit labo_accueil_path

      assert_selector "[data-fond=diorama]"
      assert_equal "toits-v1", evaluate_script("#{CONTROLEUR}.style")
      find(".acc-rond-calques").click
      assert find("input[name=calques-style][value=toits-v1]", visible: :all).checked?
    end
  end

  test "le style est masqué en mode Plan" do
    sur_la_carte do
      find(".acc-rond-calques").click
      assert_selector "#acc-calques fieldset[data-rubrique=style]", visible: true
      within("#acc-calques") { find("label.acc-calques-option", text: "Plan").click }
      assert_selector "#acc-calques fieldset[data-rubrique=style]", visible: false
    end
  end

  test "l'économiseur de données démarre sur le plan, tant qu'aucun choix n'est gardé" do
    navigateur = page.driver.browser
    script = navigateur.execute_cdp("Page.addScriptToEvaluateOnNewDocument",
                                    source: "Object.defineProperty(navigator, 'connection', { value: { saveData: true } })")
    sur_la_carte do
      assert_selector "[data-fond=plan]"
      choisir_fond "Diorama"
      visit labo_accueil_path
      assert_selector "[data-fond=diorama]"
    end
  ensure
    navigateur&.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script["identifier"]) if script
  end
end
