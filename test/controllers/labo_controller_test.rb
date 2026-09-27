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
    assert_select "nav.acc-onglets"
    # Panneau « Calques » : Fond (Diorama, Plan) et Ambiance complète (Automatique, moment, saison,
    # météo, maquette blanche) ; pas encore de Style.
    assert_select ".acc-rond-calques[aria-controls=acc-calques]"
    assert_select "#acc-calques[hidden] [data-rubrique]", 2
    assert_select "#acc-calques [data-rubrique=style]", 0
    assert_select "input[name=calques-fond]", 2
    assert_select "input[data-diorama-target=choixAuto][role=switch]"
    assert_select "input[name=calques-moment]" do |choix|
      assert_equal %w[aube jour heure-doree heure-bleue nuit], choix.map { |c| c["value"] }
    end
    assert_select "input[name=calques-saison]" do |choix|
      assert_equal %w[printemps-ete automne hiver], choix.map { |c| c["value"] }
    end
    assert_select "input[name=calques-meteo]" do |choix|
      assert_equal %w[clair pluie neige], choix.map { |c| c["value"] }
    end
    assert_select "input[data-diorama-target=choixBlanche][role=switch]"
  end

  test "sans étalonnage publié : moments paramétriques et météo seulement, pas de maquette blanche" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    tuiles = DioramaTuiles.new(base: base, sonde: ->(url) { url == "#{base}/toits-v1/manifeste.json" })
    DioramaTuiles.stub(:new, tuiles) { get labo_accueil_url }

    assert_response :success
    assert_select "input[name=calques-fond]", 2
    assert_select "input[name=calques-moment]" do |choix|
      assert_equal %w[aube jour heure-doree nuit], choix.map { |c| c["value"] }
    end
    assert_select "input[name=calques-saison]", 1
    assert_select "input[name=calques-meteo]", 3
    assert_select "input[data-diorama-target=choixBlanche]", 0
  end

  test "sans diorama publié, la rubrique Ambiance n'est pas rendue" do
    tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
    DioramaTuiles.stub(:new, tuiles) { get labo_accueil_url }

    assert_select "input[name=calques-fond]", 2
    assert_select "[data-rubrique=ambiance]", 0
  end

  test "une ambiance absente du domaine n'est pas proposée" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    tuiles = DioramaTuiles.new(base: base, sonde: ->(url) { !url.end_with?("hiver-actuelle.json") })
    DioramaTuiles.stub(:new, tuiles) { get labo_accueil_url }

    assert_select "input[name=calques-saison]" do |choix|
      assert_equal %w[printemps-ete automne], choix.map { |c| c["value"] }
    end
  end
end
