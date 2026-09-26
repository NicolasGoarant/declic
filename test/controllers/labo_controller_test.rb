require "test_helper"
require "minitest/mock"

class LaboControllerTest < ActionDispatch::IntegrationTest
  test "la page d'accueil diorama répond, hors index, avec sa propre mise en page" do
    # Aucune requête réseau en test : toutes les couches sont déclarées présentes.
    tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { true })
    DioramaTuiles.stub(:new, tuiles) { get labo_accueil_url }

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "[data-controller=diorama]"
    assert_select ".acc-cat", 6
    assert_select ".acc-bascule"
    assert_select "nav.acc-onglets"
  end

  test "sans maquette blanche publiée, la bascule n'est pas rendue" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    tuiles = DioramaTuiles.new(base: base, sonde: ->(url) { url == "#{base}/toits-v1/manifeste.json" })
    DioramaTuiles.stub(:new, tuiles) { get labo_accueil_url }

    assert_response :success
    assert_select ".acc-bascule", 0
    assert_select ".acc-ambiance", 0
  end
end
