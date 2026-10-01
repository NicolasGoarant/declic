require "application_system_test_case"

# Géolocalisation automatique à l'arrivée (app/javascript/geoloc_auto.js) : demandée une seule fois par
# navigateur, silencieuse en cas d'échec. navigator.geolocation est remplacé avant les scripts de la page.
class GeolocAutoTest < ApplicationSystemTestCase
  def simuler_geolocalisation(reponse)
    # Navigateur neuf : le même Chrome sert à tous les tests.
    visit "/robots.txt"
    page.execute_script("localStorage.clear(); sessionStorage.clear()")
    source = <<~JS
      (() => {
        const n = () => Number(sessionStorage.getItem("appels-geoloc") || 0)
        const faux = {
          getCurrentPosition(ok, ko) {
            sessionStorage.setItem("appels-geoloc", n() + 1)
            #{reponse == :succes ? "ok({ coords: { latitude: 48.6937, longitude: 6.1834 } })" : "ko({ code: 1, message: 'refus' })"}
          }
        }
        Object.defineProperty(navigator, "geolocation", { value: faux, configurable: true })
        Object.defineProperty(navigator, "permissions", { value: undefined, configurable: true })
      })()
    JS
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: source)
  end

  def appels = page.evaluate_script("Number(sessionStorage.getItem('appels-geoloc') || 0)")

  test "la position est demandée d'office et publiée à la page" do
    simuler_geolocalisation(:succes)
    visit philosophie_path
    assert_equal 1, appels
    assert_equal 48.6937, page.evaluate_script("window.declicPosition.lat")
  end

  test "un refus est silencieux et la demande n'est pas relancée à la navigation suivante" do
    simuler_geolocalisation(:refus)
    visit philosophie_path
    assert_equal 1, appels
    assert page.evaluate_script("window.declicPosition === undefined")
    visit sponsors_path
    assert_equal 1, appels
    assert_no_text "indisponible"
  end
end
