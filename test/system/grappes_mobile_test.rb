require "application_system_test_case"
require "minitest/mock"

# La bulle « N opportunités ici » sur petit écran (diorama_controller#ouvrirPanneauGrappe) : un panneau fixe, entier
# dans l'écran quelle que soit la position de la grappe et le défilement de la page, à liste défilante.
# (Avant : popup Leaflet accrochée à la carte, qui défile avec la page : page défilée, le haut sortait de l'écran.)
class GrappesMobileTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze
  BARRE_ONGLETS = 64 # --tabbar-h, hors zone de sécurité

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(390, 844)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
    base = { description: "Une initiative.", is_active: true, location: "Nancy", category: "decouvrir" }
    10.times { |i| Opportunity.create!(base.merge(title: "Même lieu #{i + 1} avec un titre assez long pour passer à la ligne", latitude: 48.6936, longitude: 6.1833, starts_on: Date.current + i)) }
  end

  def sur_la_carte(&bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit root_path
      assert_selector ".bouquet-plus", minimum: 1, wait: 10
      bloc.call
    end
  end

  # Place la pastille à `cible` px du haut de l'écran, la page défilée de `defile` px, puis la touche.
  def ouvrir_a(cible, defile)
    execute_script("window.scrollTo(0, #{defile})")
    y = evaluate_script('document.querySelector(".bouquet-plus").getBoundingClientRect().top + 10')
    execute_script("#{CONTROLEUR}.carte.panBy([0, #{cible - y.round}], { animate: false })")
    assert_selector ".bouquet-plus", visible: :all, wait: 5
    execute_script('document.querySelector(".bouquet-plus").click()')
    assert_selector ".grappe-panneau .grappe-ligne", count: 10, wait: 5
  end

  def rectangle(selecteur)
    evaluate_script("(() => { const r = document.querySelector('#{selecteur}').getBoundingClientRect(); return { haut: r.top, bas: r.bottom, gauche: r.left, droite: r.right } })()")
  end

  test "le panneau reste entièrement à l'écran, grappe en haut, au milieu ou en bas, page défilée ou non" do
    sur_la_carte do
      [ 120, 400, 650 ].product([ 0, 256 ]).each do |cible, defile|
        ouvrir_a(cible, defile)
        r = rectangle(".grappe-panneau")
        largeur, hauteur = evaluate_script("[innerWidth, innerHeight]")
        contexte = "grappe à #{cible}px, page défilée de #{defile}px : #{r.inspect}"
        assert_operator r["haut"], :>=, 0, contexte
        assert_operator r["gauche"], :>=, 0, contexte
        assert_operator r["droite"], :<=, largeur, contexte
        assert_operator r["bas"], :<=, hauteur - BARRE_ONGLETS, contexte # au-dessus de la barre d'onglets
        assert_operator r["bas"] - r["haut"], :<=, hauteur * 0.6 + 1, contexte
        titre = rectangle(".grappe-titre")
        assert_operator titre["haut"], :>=, 0, contexte
        find("body").send_keys(:escape)
        assert_no_selector ".grappe-panneau"
      end
    end
  end

  test "la liste défile jusqu'à la dernière fiche, et reste accessible quand la page est défilée" do
    sur_la_carte do
      ouvrir_a(400, 256)
      assert evaluate_script('(() => { const l = document.querySelector(".grappe-liste"); return l.scrollHeight > l.clientHeight && getComputedStyle(l).overflowY === "auto" })()')
      dernier = evaluate_script('(() => { const l = document.querySelector(".grappe-liste"); l.scrollTop = l.scrollHeight; const a = [...l.querySelectorAll("a")].pop().getBoundingClientRect(), c = l.getBoundingClientRect(); return a.bottom <= c.bottom + 1 && a.top >= c.top })()')
      assert dernier, "la dernière ligne doit pouvoir être amenée dans la zone visible de la liste"
      assert first(".grappe-ligne")[:href].include?("/opportunities/")
    end
  end

  test "la croix, Échap et un toucher en dehors ferment le panneau" do
    sur_la_carte do
      ouvrir_a(400, 0)
      find(".grappe-fermer").click
      assert_no_selector ".grappe-panneau"

      ouvrir_a(400, 0)
      find("body").send_keys(:escape)
      assert_no_selector ".grappe-panneau"

      ouvrir_a(400, 0)
      # un toucher sur la carte, loin du panneau (qui occupe le bas de l'écran)
      page.driver.browser.action.move_to_location(200, 60).click.perform
      assert_no_selector ".grappe-panneau"
    end
  end
end
