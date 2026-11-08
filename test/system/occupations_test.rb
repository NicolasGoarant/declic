require "application_system_test_case"
require "minitest/mock"

# Les occupations saisonnières des places (config/diorama/occupations_places.yml) sur le diorama de l'accueil : posées
# selon le jour (?occupations-jour= pour choisir le jour), visibles aux niveaux de leur liste, coupées par ?occupations=0.
class OccupationsTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(1280, 900)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
  end

  def accueil(requete)
    DioramaTuiles.stub(:new, @tuiles) do
      visit root_path(requete)
      assert_selector "[data-controller~=diorama][data-fond=diorama]"
      yield
    end
  end

  def ids = evaluate_script("window.__dioramaOccupations ? window.__dioramaOccupations.ids() : null")

  test "pendant les Fêtes, les quatre installations sont posées, et leurs images visibles au zoom de la vue" do
    accueil("occupations-jour" => "2026-12-01") do
      assert_equal %w[sapin-stanislas-2026 grande-roue-carriere-2026 patinoire-carriere-2026 marche-noel-charles-iii-2026], ids
      zoom = evaluate_script("#{CONTROLEUR}.carte.getZoom()")
      assert_includes 6..9, zoom
      assert_selector "img.diorama-occupation", minimum: 4, visible: :all, wait: 10
    end
  end

  test "avant les Fêtes, seul le sapin (installé le 06/11) est posé ; après le 03/01, plus rien" do
    accueil("occupations-jour" => "2026-11-10") { assert_equal %w[sapin-stanislas-2026], ids }
    accueil("occupations-jour" => "2027-01-04") { assert_equal [], ids }
  end

  test "hors de la liste des zooms, les images sont retirées" do
    accueil("occupations-jour" => "2026-12-01") do
      assert_selector "img.diorama-occupation", minimum: 4, visible: :all, wait: 10
      execute_script("#{CONTROLEUR}.carte.setZoom(4, { animate: false })")
      assert_no_selector "img.diorama-occupation", visible: :all, wait: 5
    end
  end

  test "?occupations=0 ne les pose pas" do
    accueil("occupations-jour" => "2026-12-01", "occupations" => "0") { assert_nil ids }
  end
end
