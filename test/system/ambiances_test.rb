require "application_system_test_case"
require "minitest/mock"

# L'ambiance du diorama (/labo/accueil, panneau « Calques ») : moment, saison et météo se cumulent et
# sont gardés sur l'appareil ; « Automatique » lit le soleil, la date et Open-Meteo, et se replie sur
# « clair » sans Open-Meteo ; sans animation demandée, pas de particules. Le diorama est servi par
# TuilesFactices (hiver publié, pas d'automne ni d'heure bleue) ; Open-Meteo n'est jamais appelé
# pour de vrai : fetch est remplacé avant le chargement de la page.
class AmbiancesTest < ApplicationSystemTestCase
  CONTROLEUR = 'window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=diorama]"), "diorama")'.freeze

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    page.driver.browser.manage.window.resize_to(1280, 900)
    @tuiles = DioramaTuiles.new(base: TuilesFactices::PREFIXE, sonde: TuilesFactices.sonde)
    Opportunity.create!(title: "Jardin partagé", description: "Une initiative.", is_active: true, location: "Nancy",
                        category: "ecologie", latitude: 48.6936, longitude: 6.1833)
    @scripts = []
  end

  teardown do
    @scripts.each { |id| page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: id) }
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  # Open-Meteo : `reponse` (code WMO) ou, sans code, une panne réseau.
  def open_meteo(code = nil)
    reponse = code ? "Promise.resolve(new Response(JSON.stringify({ current: { weather_code: #{code} } })))" : "Promise.reject(new TypeError('hors ligne'))"
    source = <<~JS
      window.appelsOpenMeteo = 0
      const fetchReel = window.fetch
      window.fetch = (url, options) => String(url).includes("open-meteo") ? (window.appelsOpenMeteo++, #{reponse}) : fetchReel(url, options)
    JS
    @scripts << page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: source)["identifier"]
  end

  # Fige l'horloge du navigateur (Date) avant le chargement de la page : le moment « Automatique » (soleil à
  # Nancy) ne dépend plus de l'heure à laquelle la suite tourne (coucher du soleil, heure bleue, aube).
  def fige_heure(iso)
    source = <<~JS
      (() => {
        const Reel = Date, t0 = new Reel("#{iso}").getTime()
        class DateFigee extends Reel {
          constructor(...args) { args.length ? super(...args) : super(t0) }
          static now() { return t0 }
        }
        window.Date = DateFigee
      })()
    JS
    @scripts << page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: source)["identifier"]
  end

  def moment_auto = evaluate_async_script('import("diorama/soleil").then((s) => arguments[0](s.momentAuto()))')

  def sur_la_carte(&bloc)
    DioramaTuiles.stub(:new, @tuiles) do
      visit root_path
      assert_selector "[data-controller~=diorama][data-fond=diorama]"
      bloc.call
    end
  end

  def ouvrir_calques
    find(".acc-rond-calques").click
    assert_selector "#acc-calques", visible: true
  end

  def choisir(libelle, reglage)
    within("#acc-calques") { find("label.acc-calques-puce", text: libelle, exact_text: true) { |l| l.has_css?("input[name=calques-#{reglage}]", visible: :all) }.click }
  end

  def etat = evaluate_script("#{CONTROLEUR}.etat")
  def particules = evaluate_script("#{CONTROLEUR}.precipitations?.nombre ?? 0")
  def coche?(reglage, valeur) = find("input[name=calques-#{reglage}][value=#{valeur}]", visible: :all).checked?

  test "moment, saison et météo se cumulent, et sont gardés sur l'appareil" do
    sur_la_carte do
      ouvrir_calques
      assert_no_selector "input[name=calques-saison][value=automne]", visible: :all # non publié ici
      choisir "Nuit", "moment"
      choisir "Hiver", "saison"
      choisir "Neige", "meteo"

      assert_equal({ "moment" => "nuit", "saison" => "hiver", "meteo" => "neige" }, etat)
      assert_selector "[data-controller~=diorama][data-moment=nuit]"
      assert_selector ".acc-precipitations", visible: :all
      assert_operator particules, :>, 0
      assert_equal %w[nuit hiver neige], evaluate_script("['moment', 'saison', 'meteo'].map((r) => localStorage.getItem('declic:' + r))")

      visit root_path

      assert_selector "[data-controller~=diorama][data-moment=nuit]"
      assert_equal({ "moment" => "nuit", "saison" => "hiver", "meteo" => "neige" }, etat)
      ouvrir_calques
      assert coche?("moment", "nuit")
      assert coche?("saison", "hiver")
      assert coche?("meteo", "neige")
    end
  end

  test "la maquette blanche coupe les particules, un réglage d'ambiance la quitte" do
    sur_la_carte do
      ouvrir_calques
      choisir "Printemps-été", "saison" # l'automatique de départ dépend de la date du jour
      choisir "Pluie", "meteo"
      assert_operator particules, :>, 0
      find("label.acc-calques-interrupteur", text: "Maquette blanche").click
      assert_equal 0, particules
      choisir "Aube", "moment"
      refute find("input[role=switch][data-diorama-target=choixBlanche]", visible: :all).checked?
      assert_equal({ "moment" => "aube", "saison" => "printemps-ete", "meteo" => "pluie" }, etat)
      assert_operator particules, :>, 0
    end
  end

  test "Automatique : météo réelle d'Open-Meteo, dite en clair, et gardée 30 minutes" do
    open_meteo(63) # pluie modérée
    sur_la_carte do
      ouvrir_calques # automatique par défaut : rien à cocher, rien de gardé sur l'appareil
      assert find("input[data-diorama-target=choixAuto]", visible: :all).checked?
      assert_selector "[data-diorama-target=ambianceAuto]", text: /: .+ d(e |')\S+, pluie\z/
      assert_equal "pluie", etat["meteo"]
      assert_nil evaluate_script("localStorage.getItem('declic:ambiance-auto')")

      visit root_path

      assert_selector "[data-controller~=diorama][data-moment]"
      assert_equal "pluie", etat["meteo"]
      assert_equal 0, evaluate_script("window.appelsOpenMeteo") # servi par le cache de 30 minutes
    end
  end

  test "Automatique sans Open-Meteo : repli sur ciel clair, sans erreur" do
    open_meteo # panne réseau
    sur_la_carte do
      ouvrir_calques
      assert_selector "[data-diorama-target=ambianceAuto]", text: /, ciel clair\z/
      assert_equal "clair", etat["meteo"]
      assert_equal 1, evaluate_script("window.appelsOpenMeteo")
      assert_nil evaluate_script("localStorage.getItem('declic:meteo-auto')") # un échec ne se garde pas

      choisir "Neige", "meteo" # un choix à la main quitte l'automatique
      refute find("input[data-diorama-target=choixAuto]", visible: :all).checked?
      assert_equal "neige", etat["meteo"]
      assert_equal "0", evaluate_script("localStorage.getItem('declic:ambiance-auto')")
    end
  end

  test "un choix à la main fait sous un autre ciel est échu : retour à l'automatique" do
    fige_heure("2026-11-16T12:00:00+01:00") # plein jour : le résultat ne dépend plus du coucher du soleil
    sur_la_carte do
      # un soir d'essais : « nuit » choisie à la main, sous un ciel qui n'est plus celui de maintenant
      execute_script(<<~JS)
        localStorage.setItem("declic:ambiance-auto", "0")
        localStorage.setItem("declic:moment", "nuit")
        localStorage.setItem("declic:ambiance-choisie-sous", "un-autre-moment")
      JS
      visit root_path

      assert_selector "[data-controller~=diorama][data-moment]"
      assert evaluate_script("#{CONTROLEUR}.auto")
      assert_equal evaluate_async_script('import("diorama/soleil").then((s) => arguments[0](s.momentAuto()))'), etat["moment"]
      assert_equal "1", evaluate_script("localStorage.getItem('declic:ambiance-auto')")
    end
  end

  test "moins d'animations demandé : neige sans particules" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    sur_la_carte do
      ouvrir_calques
      choisir "Neige", "meteo"
      assert_equal "neige", etat["meteo"]
      assert_no_selector ".acc-precipitations", visible: :all
      assert_equal 0, particules
    end
  end

  # Nuages et brouillard (diorama/voiles, 03/11/2026) : des toiles ancrées au sol dans le volet météo, sans toucher la dalle.
  def toile?(classe) = evaluate_script("Boolean(document.querySelector('.leaflet-pane .#{classe}'))")

  test "nuages de jour seulement, brouillard à toute heure, et la dalle reste celle du ciel clair" do
    sur_la_carte do
      ouvrir_calques
      choisir "Jour", "moment"
      choisir "Nuageux", "meteo"
      assert_equal "nuageux", etat["meteo"]
      assert_selector ".acc-nuages", visible: :all
      assert_equal "0.22", evaluate_script("#{CONTROLEUR}.nuages.opacite.toFixed(2)")
      assert_operator evaluate_script("#{CONTROLEUR}.nuages.stats.bulles"), :>, 0 # des ombres réellement posées
      assert_equal 0, particules
      choisir "Nuit", "moment"
      assert_no_selector ".acc-nuages", visible: :all, wait: 5 # retrait en fondu
      choisir "Brouillard", "meteo"
      assert_selector ".acc-brouillard", visible: :all
      assert_equal "brouillard", etat["meteo"]
      assert_equal 0, particules
      choisir "Pluie", "meteo"
      assert_no_selector ".acc-brouillard", visible: :all, wait: 5
      assert_operator particules, :>, 0
    end
  end

  test "Open-Meteo dit brouillard (45) : brouillard en automatique, coupé par ?brouillard=0" do
    open_meteo(45)
    sur_la_carte do
      assert_selector "[data-diorama-target=ambianceAuto]", text: /, brouillard\z/, visible: :all
      assert_equal "brouillard", etat["meteo"]
      assert_selector ".acc-brouillard", visible: :all
      visit root_path(brouillard: 0)
      assert_selector "[data-controller~=diorama][data-moment]"
      assert_equal "brouillard", etat["meteo"]
      assert_no_selector ".acc-brouillard", visible: :all
    end
  end

  test "moins d'animations demandé : ni nuages ni brouillard" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    sur_la_carte do
      ouvrir_calques
      choisir "Jour", "moment"
      choisir "Nuageux", "meteo"
      assert_equal "nuageux", etat["meteo"]
      choisir "Brouillard", "meteo"
      assert_equal "brouillard", etat["meteo"]
      assert_no_selector ".acc-nuages, .acc-brouillard", visible: :all
    end
  end

  test "le brouillard se dissipe avec le soleil, les joggeurs courent matin et soir" do
    sur_la_carte do
      r = evaluate_async_script(<<~JS)
        Promise.all([import("diorama/voiles"), import("diorama/vivants")]).then(([v, w]) => arguments[0]({
          brouillard: [-10, 0, 6, 12, 18, 30].map((h) => Math.round(v.densiteBrouillard(h, "jour") * 100) / 100),
          nuit: v.densiteBrouillard(-20, "nuit"),
          joggeurs: [3, 8, 12, 18.5, 23].map((h) => Math.round(w.facteursHoraires(h).joggeur * 100) / 100)
        }))
      JS
      assert_equal [1, 1, 0.82, 0.48, 0.3, 0.3], r["brouillard"]
      assert_equal 0.7, r["nuit"]
      assert_equal [0.03, 0.5, 0.6, 1, 0.03], r["joggeurs"]
    end
  end

  test "le mode automatique : moment selon le soleil à Nancy, saison selon la date" do
    sur_la_carte do
      resultats = evaluate_async_script(<<~JS)
        const fini = arguments[0]
        Promise.all([import("diorama/soleil"), import("diorama/meteo")]).then(([s, m]) => {
          const d = (iso) => new Date(iso)
          fini({
            midi: s.momentAuto(d("2026-09-27T11:00:00Z")),
            avantLever: s.momentAuto(d("2026-09-27T05:10:00Z")),
            matin: s.momentAuto(d("2026-09-27T06:00:00Z")),
            soir: s.momentAuto(d("2026-09-27T17:00:00Z")),
            crepuscule: s.momentAuto(d("2026-09-27T17:40:00Z")),
            nuit: s.momentAuto(d("2026-09-27T21:00:00Z")),
            juillet: s.saisonAuto(d("2026-07-14T12:00:00Z")),
            octobre: s.saisonAuto(d("2026-10-15T12:00:00Z")),
            janvier: s.saisonAuto(d("2027-01-10T12:00:00Z")),
            libelle: s.libelleAuto({ moment: "nuit", saison: "automne", meteo: "pluie" }),
            codes: [0, 1, 2, 3, 45, 48, 61, 80, 95, 71, 86].map(m.meteoDuCode)
          })
        })
      JS
      assert_equal({ "midi" => "jour", "avantLever" => "aube", "matin" => "heure-doree", "soir" => "heure-doree",
                     "crepuscule" => "heure-bleue", "nuit" => "nuit", "juillet" => "printemps-ete", "octobre" => "automne",
                     "janvier" => "hiver", "libelle" => "nuit d'automne, pluie",
                     "codes" => %w[clair clair nuageux nuageux brouillard brouillard pluie pluie pluie neige neige] }, resultats)
    end
  end

  # Le mode automatique, à heure fixe (16 novembre 2026, Nancy) : un cas par moment de la journée.
  { "jour" => "12:00", "heure-doree" => "16:30", "aube" => "07:30", "heure-bleue" => "17:25", "nuit" => "22:00" }.each do |moment, heure|
    test "Automatique à #{heure} (#{moment}) : le moment suit le soleil, sans dépendre de l'heure de la suite" do
      fige_heure("2026-11-16T#{heure}:00+01:00")
      sur_la_carte do
        assert_selector "[data-controller~=diorama][data-moment]"
        assert_equal moment, moment_auto
      end
    end
  end
end
