require "application_system_test_case"
require "minitest/mock"

# Géolocalisation à l'arrivée (app/javascript/geoloc_auto.js, bandeau_position.js) : demandée dès le
# chargement quand la permission est « prompt », relue sans invite quand elle est « granted », bandeau d'aide
# quand elle est « denied », bandeau d'invitation sans API Permissions. navigator.geolocation et
# navigator.permissions sont remplacés avant les scripts de la page (Nancy : 48.6921, 6.1844).
class GeolocAutoTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(1280, 900)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
    base = { description: "Une initiative.", is_active: true, location: "Nancy" }
    Opportunity.create!(base.merge(title: "Maraude du nord", category: "benevolat", latitude: 48.6975, longitude: 6.1844))
    Opportunity.create!(base.merge(title: "Jardin du sud", category: "ecologiser", latitude: 48.6900, longitude: 6.1844))
    Opportunity.create!(base.merge(title: "Atelier lointain", category: "formation", latitude: 48.7850, longitude: 6.1844))
  end

  # permission : "prompt", "granted", "denied" ou nil (pas d'API Permissions).
  # reponse : :succes (Nancy), :refus (code 1) ou :silence (l'utilisateur n'a pas encore répondu).
  def simuler(permission:, reponse:, refus_memorise: false)
    visit "/robots.txt" # navigateur neuf : le même Chrome sert à tous les tests
    page.execute_script("localStorage.clear(); sessionStorage.clear()")
    page.execute_script("localStorage.setItem('declic:geoloc-refus', String(Date.now()))") if refus_memorise
    appel = {
      succes: "ok({ coords: { latitude: 48.6921, longitude: 6.1844, accuracy: 20 } })",
      refus: "ko({ code: 1, message: 'refus' })",
      silence: ""
    }.fetch(reponse)
    source = <<~JS
      (() => {
        const n = () => Number(sessionStorage.getItem("appels-geoloc") || 0)
        const faux = { getCurrentPosition(ok, ko) { sessionStorage.setItem("appels-geoloc", n() + 1); #{appel} } }
        Object.defineProperty(navigator, "geolocation", { value: faux, configurable: true })
        Object.defineProperty(navigator, "permissions", {
          value: #{permission ? "{ query: async () => ({ state: '#{permission}' }) }" : "undefined"}, configurable: true
        })
      })()
    JS
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: source)
  end

  def appels = page.evaluate_script("Number(sessionStorage.getItem('appels-geoloc') || 0)")

  def sur_la_carte(chemin = root_path, &bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit chemin
      assert_selector "[data-controller~=diorama][data-fond]"
      bloc.call
    end
  end

  test "permission « prompt » : la position est demandée dès le chargement, sans bloquer la page" do
    simuler(permission: "prompt", reponse: :silence)
    sur_la_carte do
      assert_equal 1, appels
      assert_selector ".acc-localiser", text: "Me localiser"
      assert_selector ".fiche", minimum: 1 # l'accueil reste utilisable pendant l'attente
      assert_no_selector ".bandeau-position:not([hidden])"
    end
  end

  test "permission « granted » à Nancy : marqueur, recentrage, « Plus proches » actif et filtre « À proximité »" do
    simuler(permission: "granted", reponse: :succes)
    sur_la_carte do
      assert_equal 1, appels
      assert_selector ".diorama-moi"
      assert_equal 48.6921, evaluate_script("window.declicPosition.lat")
      assert_selector ".acc-pilles-position button[aria-pressed='true']", text: "Plus proches"
      assert_equal "Plus proches de vous", find("#acc-volet-titre").text

      assert_equal [ "Jardin du sud", "Maraude du nord" ], all(".acc-fiches .fiche-lien").map(&:text).first(2)

      retenus = "#{CONTROLEUR}.points.filter((p) => #{CONTROLEUR}.passe(p)).map((p) => p.titre).sort()"
      assert_includes evaluate_script(retenus), "Atelier lointain"
      click_on "À proximité"
      assert_equal [ "Jardin du sud", "Maraude du nord" ], evaluate_script(retenus) # l'atelier est à 10,4 km : écarté
    end
  end

  test "permission « denied » : bandeau d'aide fermable, « Me localiser » toujours là, aucune erreur" do
    simuler(permission: "denied", reponse: :refus)
    sur_la_carte do
      assert_equal 0, appels
      assert_selector ".bandeau-position", text: "Position désactivée. Pour trouver les opportunités près de vous, réactivez la position dans le cadenas de la barre d'adresse."
      assert_selector ".acc-localiser", text: "Me localiser"
      erreurs = page.driver.browser.logs.get(:browser).select { |l| l.level == "SEVERE" && l.message !~ /tuiles|favicon|ERR_|404/ }
      assert_empty erreurs.map(&:message)
      find(".bandeau-position-fermer").click
      assert_no_selector ".bandeau-position"
    end
  end

  test "un refus de l'utilisateur est mémorisé 7 jours : plus d'appel automatique" do
    simuler(permission: "prompt", reponse: :refus)
    sur_la_carte do
      assert_equal 1, appels
      assert evaluate_script("Number(localStorage.getItem('declic:geoloc-refus')) > 0")
      visit root_path
      assert_equal 1, appels # pas de nouvel appel : le compteur de session est resté à 1
    end
  end

  test "refus mémorisé : aucun appel au chargement, « Me localiser » redemande" do
    simuler(permission: "prompt", reponse: :succes, refus_memorise: true)
    sur_la_carte do
      assert_equal 0, appels
      find(".acc-localiser").click
      assert_selector ".diorama-moi"
      assert_equal 1, appels
    end
  end

  test "sans API Permissions : bandeau « Activer ma position » qui déclenche l'invite en un clic" do
    simuler(permission: nil, reponse: :succes)
    sur_la_carte do
      assert_equal 0, appels
      assert_selector ".bandeau-position", text: /partagez votre position/
      click_on "Activer ma position"
      assert_selector ".diorama-moi"
      assert_no_selector ".bandeau-position"
      assert_equal 1, appels
    end
  end

  test "Opportunités : une fois la position connue, le tri passe sur « Plus proches »" do
    simuler(permission: "granted", reponse: :succes)
    sur_la_carte(labo_opportunites_path) do
      assert_selector "select[data-explorateur-target='tri']"
      assert_equal "proches", find("select[data-explorateur-target='tri']").value
      assert_equal [ "Jardin du sud", "Maraude du nord", "Atelier lointain" ], all(".lb-carte [data-titre]").map(&:text).first(3)
    end
  end
end
