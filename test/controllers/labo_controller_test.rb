require "test_helper"
require "minitest/mock"

class LaboControllerTest < ActionDispatch::IntegrationTest
  test "la page d'accueil diorama (racine) répond, indexable, avec sa propre mise en page" do
    # Aucune requête réseau en test : toutes les couches sont déclarées présentes.
    tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { true })
    DioramaTuiles.stub(:new, tuiles) { get root_url }

    assert_response :success
    assert_nil response.headers["X-Robots-Tag"]
    assert_select "[data-controller=diorama]"
    assert_select ".acc-cat", 6
    assert_select "nav.acc-onglets"
    # Panneau « Calques » : Fond (Diorama, Plan), Style (Jeu vidéo, Réaliste) et Ambiance complète
    # (Automatique, moment, saison, météo, maquette blanche).
    assert_select ".acc-rond-calques[aria-controls=acc-calques]"
    assert_select "#acc-calques[hidden] [data-rubrique]", 3
    assert_select "input[name=calques-style]" do |choix|
      assert_equal %w[jeu-video-v2 toits-v1], choix.map { |c| c["value"] }
    end
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
    DioramaTuiles.stub(:new, tuiles) { get root_url }

    assert_response :success
    assert_select "input[name=calques-fond]", 2
    assert_select "input[name=calques-style]", 1
    assert_select "input[name=calques-style][value=toits-v1]", 1
    assert_select "input[name=calques-moment]" do |choix|
      assert_equal %w[aube jour heure-doree nuit], choix.map { |c| c["value"] }
    end
    assert_select "input[name=calques-saison]", 1
    assert_select "input[name=calques-meteo]", 3
    assert_select "input[data-diorama-target=choixBlanche]", 0
  end

  test "sans diorama publié, la rubrique Ambiance n'est pas rendue" do
    tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
    DioramaTuiles.stub(:new, tuiles) { get root_url }

    assert_select "input[name=calques-fond]", 2
    assert_select "[data-rubrique=style]", 0
    assert_select "[data-rubrique=ambiance]", 0
  end

  test "une ambiance absente du domaine n'est pas proposée" do
    base = "https://tuiles.test/#{SecureRandom.hex(4)}"
    tuiles = DioramaTuiles.new(base: base, sonde: ->(url) { !url.end_with?("hiver-actuelle.json") })
    DioramaTuiles.stub(:new, tuiles) { get root_url }

    assert_select "input[name=calques-saison]" do |choix|
      assert_equal %w[printemps-ete automne], choix.map { |c| c["value"] }
    end
  end

  def accueil_sans_tuiles
    tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
    DioramaTuiles.stub(:new, tuiles) { get root_url }
    assert_response :success
  end

  def opportunite(**attrs)
    Opportunity.create!({ title: "Atelier", description: "Une description.", category: "formation", is_active: true,
                          latitude: 48.69, longitude: 6.18 }.merge(attrs))
  end

  test "les cinq blocs sous la carte, dans l'ordre de la maquette" do
    4.times { |i| Story.create!(title: "Histoire #{i}", location: "Nancy", latitude: 48.69, longitude: 6.18, is_active: true, happened_on: Date.current - i) }
    accueil_sans_tuiles

    assert_select "main.acc-suite > section.bloc" do |blocs|
      assert_equal %w[bloc-temoignages bloc-opportunites bloc-histoires bloc-impact bloc-presse], blocs.map { |b| b["class"].split[1] }
    end
    temoignages = YAML.safe_load_file(Rails.root.join("config/temoignages.yml"))
    assert_select ".bloc-temoignages [data-controller=carrousel] .tem-carte", temoignages.size
    assert_select ".tem-carte .bloc-exemple", text: "Exemple de maquette", count: temoignages.count { |t| t["placeholder"] }
    assert_select ".bloc-temoignages .bloc-fleches .bloc-rond", 2
    assert_select ".bloc-temoignages a", 0
    assert_select "section.bloc--vague" do |blocs|
      assert_equal %w[bloc-opportunites bloc-histoires bloc-impact], blocs.map { |b| b["class"].split[1] }
    end
    assert_select ".imp-chiffre", 4
    assert_select ".med-logo[role=tab]", PassagePresse::TOUS.size
    assert_select ".med-logo[aria-selected=true]", 1
    assert_select ".med-panneau[role=tabpanel] a.med-lien[target=_blank][rel=noopener]", PassagePresse::TOUS.size
    assert_select ".med-lien" do |liens|
      assert_equal PassagePresse::TOUS.map(&:url), liens.map { |l| l["href"] }
    end
    assert_select ".acc-barre-nav a" do |liens|
      assert_equal [ "Carte", "Opportunités", "Belles Histoires", "Pourquoi Déclic ?" ], liens.map { |l| l.text.strip }
      assert_equal [ "#carte", labo_opportunites_path, labo_belles_histoires_path, philosophie_path ], liens.map { |l| l["href"] }
    end
    assert_select ".acc-barre--flottante", 1
    assert_select ".acc-barre-sep + a.acc-bouton-temoignage[aria-label=?][title=?]", "Partager un témoignage", "Partager un témoignage"
    assert_select ".acc-barre a[href=?]", opportunities_path, 0
    assert_select ".acc-barre .acc-bouton-proposer", 2
    assert_select ".acc-localiser", text: /Me localiser/
  end

  test "bloc Opportunités : agenda par date, vedette et lignes filtrables, sans passées ni permanentes" do
    Opportunity.update_all(is_active: false)
    jour = Date.current
    opportunite(title: "Dans dix jours", starts_on: jour + 10)
    opportunite(title: "Demain", starts_on: jour + 1, category: "rencontres")
    opportunite(title: "Hier", starts_on: jour - 1)
    opportunite(title: "Permanente")
    opportunite(title: "Dans trois jours", starts_on: jour + 3)
    opportunite(title: "Dans un mois", starts_on: jour + 30)
    accueil_sans_tuiles

    # Vedettes : la prochaine de toutes (visible), puis la première de chaque autre catégorie (masquée).
    assert_select "[data-agenda-target=vedette]" do |vedettes|
      assert_equal [ "rencontres", "formation" ], vedettes.map { |v| v["data-categorie"] }
      assert_equal [ nil, "" ], vedettes.map { |v| v["hidden"] }
    end
    assert_select "[data-agenda-target=vedette]:not([hidden]) .opp-titre", text: "Demain"
    assert_select "[data-agenda-target=vedette]:not([hidden]) .opp-etiquette", text: "Rencontrer"
    assert_select "[data-agenda-target=vedette]:not([hidden]) img[src*='fallback-opportunity-rencontres']"
    assert_select ".agenda-ligne .agenda-titre" do |titres|
      assert_equal [ "Dans trois jours", "Dans dix jours", "Dans un mois" ], titres.map(&:text)
    end
    assert_select ".agenda-ligne[href^='/opportunities/']", 3
    assert_select ".agenda-date strong", text: (jour + 3).day.to_s
    assert_select ".bloc-filtre[aria-pressed]", 6
    assert_select ".bloc-opportunites a.bloc-bouton--jaune[href=?]", labo_opportunites_path
    assert_select ".bloc-opportunites", text: /Hier|Permanente/, count: 0
  end

  test "bloc Impact : comptages de la base au format français, prêts pour le compteur animé" do
    Story.update_all(is_active: false)
    4.times { |i| Story.create!(title: "Histoire #{i}", location: "Nancy", latitude: 48.69, longitude: 6.18, is_active: true, happened_on: Date.current - i) }
    accueil_sans_tuiles

    assert_select ".imp-chiffres[data-controller=compteur]"
    assert_select ".imp-chiffre:last-child strong[data-valeur='4']", text: "4"
    assert_select ".bloc-impact .une", 0
    assert_select ".bloc-impact a.bloc-bouton--contour-violet[href=?]", philosophie_path
  end

  test "bloc Belles Histoires : la une en grand, puis les deux plus récentes, bouton vers l'index" do
    Story.update_all(is_active: false)
    histoires = 5.times.map do |i|
      Story.create!(title: "Histoire #{i}", location: "Nancy", latitude: 48.69, longitude: 6.18, is_active: true, happened_on: Date.current - i)
    end
    accueil_sans_tuiles

    assert_select ".bento .une h3", text: "Histoire 0"
    assert_select ".bento .une a[href=?]", story_path(histoires[0]), text: /Lire l.histoire complète/
    assert_select ".bento a.opp-carte .opp-titre" do |titres|
      assert_equal [ "Histoire 1", "Histoire 2" ], titres.map(&:text)
    end
    assert_select ".bento .opp-etiquette", text: "Belle histoire", count: 2
    assert_select ".bloc-histoires a.bloc-bouton--violet[href=?]", labo_belles_histoires_path, text: /Découvrir toutes les belles histoires/

    histoires.last.update!(tags: "Portrait, À la une")
    accueil_sans_tuiles
    assert_select ".bento .une h3", text: "Histoire 4"
    assert_select ".bento a.opp-carte .opp-titre" do |titres|
      assert_equal [ "Histoire 0", "Histoire 1" ], titres.map(&:text)
    end

    Story.update_all(is_active: false)
    accueil_sans_tuiles
    assert_select ".bloc-histoires", 0
  end

  test "les nombres s'écrivent avec une espace insécable" do
    assert_equal "1\u00A0245", ApplicationController.helpers.nombre_fr(1245)
  end

  test "mobile : header logo + baseline, sans menu ; barre du bas à cinq entrées" do
    accueil_sans_tuiles

    assert_select ".acc-entete" do
      assert_select ".acc-logo", text: /Déclic/
      assert_select ".acc-baseline", text: "Changer sa vie, en quelques clics"
      assert_select "button, nav, .acc-entete-proposer", 0
      assert_select "form.acc-recherche input[type=search][placeholder=?][data-diorama-target=recherche]", "Rechercher une activité, un lieu, un événement…"
    end
    assert_select "nav.acc-onglets > *", 5
    assert_select "nav.acc-onglets > a" do |liens|
      assert_equal [ "Carte", "Opportunités", "Proposer", "Belles Histoires", "Déclic ?" ], liens.map { |l| l.text.strip }
      assert_equal [ "#carte", labo_opportunites_path, new_opportunity_path, labo_belles_histoires_path, philosophie_path ], liens.map { |l| l["href"] }
    end
    assert_select "nav.acc-onglets a[aria-current=page]", 1
    assert_select "nav.acc-onglets a.acc-onglet-plus"
    assert_select ".acc-onglets", text: /Favoris|Profil|Explorer/, count: 0
  end

  test "la barre desktop marque l'entrée de la page courante, sans Explorer" do
    { labo_opportunites_url => "Opportunités", labo_belles_histoires_url => "Belles Histoires", philosophie_url => "Pourquoi Déclic ?" }.each do |url, libelle|
      get url
      assert_select ".acc-barre--flottante", 0
      assert_select ".acc-barre-nav a[aria-current=page]", 1
      assert_select ".acc-barre-nav a[aria-current=page]", text: libelle
      assert_select ".acc-barre-nav a", text: "Explorer", count: 0
    end
  end

  test "barre du bas des fiches : même barre, entrée courante selon la page" do
    get labo_belles_histoires_url
    assert_select "nav.acc-onglets a[aria-current=page]", text: "Belles Histoires"
    get philosophie_url
    assert_select "nav.acc-onglets a[aria-current=page]", text: "Déclic ?"
  end
end
