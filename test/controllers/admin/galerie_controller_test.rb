require "test_helper"

module Admin
  class GalerieControllerTest < ActionDispatch::IntegrationTest
    IDENTIFIANTS = { user: "galerie-test", pass: "secret-de-test" }.freeze

    setup do
      @user_avant, @pass_avant = ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]
      ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = IDENTIFIANTS.values_at(:user, :pass)
      Opportunity.delete_all
      Story.delete_all

      @histoire = Story.create!(title: "Portrait en ligne", location: "Nancy", city: "Nancy", is_active: true, latitude: 48.69, longitude: 6.18)
      @opportunite = Opportunity.create!(title: "Opportunité en ligne", description: "Un atelier", category: "decouvrir", city: "Nancy",
                                         location: "Nancy", latitude: 48.69, longitude: 6.18, is_active: true)
      @propose  = candidat("Proposé jardin", enriched_at: Time.current, item_type: "opportunite", commune: "Nancy", declic_category: "ecologie", score: 77, summary: "Une phrase. Une autre.")
      @verifier = candidat("À vérifier cuisine", enriched_at: Time.current, item_type: "opportunite", commune: "Laxou", status: "a_verifier")
      @non_trie = candidat("Non trié brut")
      @ecarte   = candidat("Écarté loisir", enriched_at: Time.current, item_type: "opportunite", status: "ecarte", discard_reason: "Hors périmètre Déclic : loisir")
    end

    teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @user_avant, @pass_avant }

    def auth = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(IDENTIFIANTS[:user], IDENTIFIANTS[:pass]) }

    def candidat(titre, **attrs)
      ::Veille::Candidate.create!({ url: "https://exemple.fr/#{SecureRandom.hex(4)}", title: titre, origin: "agenda_nancy", full_text: "Texte." }.merge(attrs))
    end

    def texte = CGI.unescapeHTML(response.body)


    test "l'accès est protégé comme /admin/veille" do
      get admin_galerie_path
      assert_response :unauthorized
      get admin_galerie_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("x", "y") }
      assert_response :unauthorized
      get admin_galerie_path, headers: auth
      assert_response :success
    end

    test "sans identifiants configurés : 403" do
      ENV["ADMIN_USERNAME"] = ""
      get admin_galerie_path, headers: auth
      assert_response :forbidden
    end

    test "affiche les quatre statuts, sans les écartés par défaut" do
      get admin_galerie_path, headers: auth
      assert_response :success
      assert_match "Portrait en ligne", texte
      assert_match "Opportunité en ligne", texte
      assert_match "Proposé jardin", texte
      assert_match "À vérifier cuisine", texte
      assert_match "Non trié brut", texte
      assert_no_match(/Écarté loisir/, texte)
      %w[s-en_ligne s-propose s-a_verifier s-non_trie].each { |classe| assert_select "article .pastille.statut.#{classe}" }
      assert_select "article .pastille.type", text: "Opportunité"
      assert_select "article .pastille.type", text: "Belle Histoire"
      assert_match "Score IA : 77/100", texte
    end

    test "les compteurs donnent le total et le détail par type" do
      galerie = ::Galerie.new
      assert_equal({ total: 2, "opportunite" => 1, "belle_histoire" => 1 }, galerie.compteurs["en_ligne"])
      assert_equal 1, galerie.compteurs["propose"][:total]
      assert_equal 1, galerie.compteurs["a_verifier"][:total]
      assert_equal 1, galerie.compteurs["non_trie"][:total]
      assert_equal 1, galerie.compteurs["ecarte"][:total]
      get admin_galerie_path, headers: auth
      assert_select "#compteurs-galerie strong", text: "2"
    end

    test "le filtre de statut fait apparaître les écartés" do
      get admin_galerie_path(statut: "ecarte"), headers: auth
      assert_match "Écarté loisir", texte
      assert_no_match(/Proposé jardin/, texte)
      assert_match "Hors périmètre Déclic", texte
    end

    test "filtres : type, commune, recherche, tri par score" do
      get admin_galerie_path(type: "belle_histoire"), headers: auth
      assert_match "Portrait en ligne", texte
      assert_no_match(/Proposé jardin/, texte)

      get admin_galerie_path(commune: "Laxou"), headers: auth
      assert_match "À vérifier cuisine", texte
      assert_no_match(/Portrait en ligne/, texte)

      get admin_galerie_path(q: "ATELIER"), headers: auth
      assert_match "Opportunité en ligne", texte
      assert_no_match(/Portrait en ligne/, texte)

      assert_equal @propose, ::Galerie.new(tri: "score").cartes.first.record
    end

    test "actions des cartes : fiche en ligne vs candidats" do
      get admin_galerie_path, headers: auth
      assert_select "a[href=?]", story_path(@histoire), text: "Voir sur le site ↗"
      assert_select "form[action=?]", valider_admin_veille_candidate_path(@propose)
      assert_select "form[action=?]", ecarter_admin_veille_candidate_path(@propose)
      assert_select "a[href^=?]", admin_veille_candidate_path(@propose), text: "Aperçu"
      assert_select "a[href^=?]", admin_veille_candidate_path(@propose), text: "Modifier"
    end

    test "pagination de 48 éléments" do
      50.times { |i| candidat("Lot #{i}") }
      get admin_galerie_path, headers: auth
      assert_select "article.carte-galerie", 48
      get admin_galerie_path(page: 2), headers: auth
      assert_select "article.carte-galerie", 7 # 5 fiches et candidats + 50 lots = 55, écarté exclu
    end

    test "Écarter depuis la galerie y revient" do
      patch ecarter_admin_veille_candidate_path(@propose), headers: auth.merge("HTTP_REFERER" => admin_galerie_url)
      assert_redirected_to admin_galerie_url
      assert @propose.reload.ecarte?
    end

    test "candidat non trié : Relire à la place de Valider ; candidat trié : Valider" do
      get admin_galerie_path, headers: auth
      assert_select "a", text: "Relire"
      assert_select "form[action=?]", valider_admin_veille_candidate_path(@non_trie), 0
      assert_select "form[action=?]", valider_admin_veille_candidate_path(@propose)
      assert_select "a[href*=?]", admin_veille_candidate_path(@non_trie), text: "Relire"
    end

    test "pagination en haut et en bas, avec total, filtres conservés" do
      50.times { |i| candidat("Lot #{i}") }
      get admin_galerie_path(statut: "non_trie"), headers: auth
      assert_select "nav.pagination-admin", 2
      get admin_galerie_path(page: 2), headers: auth
      assert_select "nav.pagination-admin", 2
      assert_select "nav.pagination-admin", text: /49 - 55 sur 55/, count: 2
      assert_select "nav.pagination-admin a[href^=?]", "/admin/galerie?page=1", text: "‹ Précédent", count: 2
    end

    test "les cartes sans photo montrent le repli illustré de la catégorie, et gardent le retour" do
      get admin_galerie_path(statut: "en_ligne"), headers: auth
      assert_select "article .visuel svg.illustration-repli", 2
      assert_select "a[href*=?]", "retour=%2Fadmin%2Fgalerie", text: "Modifier"
    end

    test "boutons de création en tête de page" do
      get admin_galerie_path, headers: auth
      assert_select "a", text: /Nouvelle opportunité/
      assert_select "a", text: /Nouvelle Belle Histoire/
    end

    test "retour accepté seulement vers /admin" do
      patch admin_opportunity_path(@opportunite), params: { retour: "https://evil.example/", opportunity: { title: "Titre bis" } }, headers: auth
      assert_redirected_to admin_opportunities_path
      patch admin_opportunity_path(@opportunite.reload), params: { retour: "/admin/galerie?page=2", opportunity: { title: "Titre ter" } }, headers: auth
      assert_redirected_to "/admin/galerie?page=2"
    end

    # ---- Enchaînement des candidats depuis l'écran d'édition ----
    def liste = admin_galerie_path(statut: "a_relire", tri: "score")

    test "l'écran d'un candidat propose Précédent et Suivant dans la liste filtrée" do
      get admin_veille_candidate_path(@propose, retour: liste), headers: auth
      assert_select "a[href=?]", liste, text: "← Retour à la galerie"
      assert_select "a[href^=?]", admin_veille_candidate_path(@verifier), text: "Suivant →"
      assert_select "a", text: "← Précédent", count: 0
      assert_match "1 sur 2", texte

      get admin_veille_candidate_path(@verifier, retour: liste), headers: auth
      assert_select "a[href^=?]", admin_veille_candidate_path(@propose), text: "← Précédent"
      assert_select "a", text: "Suivant →", count: 0
    end

    test "après Écarter depuis l'écran du candidat : candidat suivant, puis galerie en fin de liste" do
      patch ecarter_admin_veille_candidate_path(@propose), params: { enchainer: 1, retour: liste }, headers: auth
      assert @propose.reload.ecarte?
      assert_response :see_other
      assert_match %r{\A#{Regexp.escape(admin_veille_candidate_path(@verifier))}\?}, response.location.sub("http://www.example.com", "")

      patch ecarter_admin_veille_candidate_path(@verifier), params: { enchainer: 1, retour: liste }, headers: auth
      assert_redirected_to liste
    end

    test "après Valider depuis l'écran du candidat : candidat suivant" do
      patch ecarter_admin_veille_candidate_path(@verifier), headers: auth # un seul candidat à relire restera : @propose
      get admin_veille_candidate_path(@propose, retour: liste), headers: auth
      assert_select "a", text: "Suivant →", count: 0
      post valider_admin_veille_candidate_path(@propose), params: { enchainer: 1, retour: liste }, headers: auth
      assert_redirected_to liste
      assert @propose.reload.publie?
    end

    test "Valider avec suivant : redirige vers le candidat suivant" do
      post valider_admin_veille_candidate_path(@propose), params: { enchainer: 1, retour: liste }, headers: auth
      assert_match %r{\A#{Regexp.escape(admin_veille_candidate_path(@verifier))}\?}, response.location.sub("http://www.example.com", "")
    end

    # ---- Navigation ----
    test "navigation principale resserrée, sans « Relecture », entrée active surlignée" do
      get admin_galerie_path, headers: auth
      assert_select "header > .container a", text: "Relecture", count: 0
      assert_select "header > .container a.on", text: "Galerie"
      assert_select "header > .container a", text: "Sources"
      assert_select "header nav.sous-nav", 0
    end

    test "Presse, Communes et Sources collectées : seconde rangée d'onglets sous « Sources »" do
      { "/admin/veille/presse" => "Presse", "/admin/veille/communes" => "Communes", "/admin/veille/sources" => "Sources collectées" }.each do |chemin, onglet|
        get chemin, headers: auth
        assert_response :success
        assert_select "header > .container a.on", text: "Sources"
        assert_select "header nav.sous-nav a.on", text: onglet
        assert_select "header nav.sous-nav a", 3
      end
    end

    test "l'écran d'un candidat garde « Galerie » surlignée" do
      get admin_veille_candidate_path(@propose), headers: auth
      assert_select "header > .container a.on", text: "Galerie"
    end

    # ---- Classement : badges, mini-formulaire, écran du candidat ----

    test "badge de type et de catégorie aux couleurs du site public ; la Belle Histoire n'a que le type" do
      get admin_galerie_path, headers: auth
      assert_select "article .badge.cat[style*='#82C162']", text: "Écologie"
      assert_select "article:has(.pastille.type:contains('Belle Histoire')) .badge.cat", 0
      assert_select "article:has(.pastille.type:contains('Belle Histoire')) .pastille.type", text: "Belle Histoire"
    end

    test "classer une opportunité enregistre type et catégorie, et les verrouille face à l'IA" do
      patch classer_admin_veille_candidate_path(@non_trie), params: { item_type: "opportunite", declic_category: "formation" }, headers: auth
      c = @non_trie.reload
      assert_equal %w[opportunite formation], [c.item_type, c.declic_category]
      assert c.classement_manuel?
    end

    test "classer une Belle Histoire ignore la catégorie" do
      patch classer_admin_veille_candidate_path(@non_trie), params: { item_type: "belle_histoire", declic_category: "formation" }, headers: auth
      assert_equal ["belle_histoire", nil], [@non_trie.reload.item_type, @non_trie.declic_category]
    end

    test "classer une opportunité sans catégorie est refusé" do
      patch classer_admin_veille_candidate_path(@non_trie), params: { item_type: "opportunite", declic_category: "" }, headers: auth
      assert_nil @non_trie.reload.item_type
      assert_equal "Choisis une catégorie pour une opportunité.", flash[:alert]
    end

    test "l'écran d'un candidat non classé propose le bloc Classement, sans aperçu ; une fois classé, l'aperçu apparaît" do
      @non_trie.update!(commune: "Nancy", summary: "Un atelier de réparation.")
      get admin_veille_candidate_path(@non_trie), headers: auth
      assert_select "fieldset.classement select[name=item_type]"
      assert_select "fieldset.classement select[name=declic_category]"
      assert_match "élément non classé", texte
      assert_select "iframe[title='Aperçu de la fiche']", 0

      patch completer_admin_veille_candidate_path(@non_trie), params: { item_type: "opportunite", declic_category: "ecologie", commune: "Nancy" }, headers: auth
      follow_redirect!(headers: auth)
      assert_select "iframe[title='Aperçu de la fiche']"
      assert @non_trie.reload.classement_manuel?
    end

    test "réenregistrer l'écran sans toucher au classement ne le verrouille pas" do
      patch completer_admin_veille_candidate_path(@propose), params: { item_type: "opportunite", declic_category: "ecologie", title: "Autre titre" }, headers: auth
      assert_not @propose.reload.classement_manuel?
    end

    # ---- Dates d'événement : créneau, tri, filtre Période ----

    def creer_opportunite(titre, **dates)
      Opportunity.create!({ title: titre, description: "x", category: "decouvrir", city: "Nancy", location: "Nancy",
                            latitude: 48.69, longitude: 6.18, is_active: true }.merge(dates))
    end

    test "la carte affiche la date de l'événement, la périodicité et, à part, la date d'ajout" do
      candidat("Chefs-d'œuvre", enriched_at: Time.current, item_type: "opportunite", commune: "Nancy", declic_category: "decouvrir",
               starts_on: Date.new(2026, 10, 10), ends_on: Date.new(2027, 3, 28), schedule_text: "tous les samedis et dimanches",
               start_time: Time.utc(2000, 1, 1, 11), end_time: Time.utc(2000, 1, 1, 12))
      candidat("Visites épicées", enriched_at: Time.current, item_type: "opportunite", commune: "Nancy", starts_on: Date.new(2026, 11, 28))
      get admin_galerie_path, headers: auth
      assert_select "article:has(h3:contains('Chefs-d')) .creneau strong", text: "Du 10 oct. 2026 au 28 mars 2027"
      assert_select "article:has(h3:contains('Chefs-d')) .creneau .small", text: "tous les samedis et dimanches, 11h-12h"
      assert_select "article:has(h3:contains('Visites')) .creneau strong", text: "Sam. 28 nov. 2026"
      assert_select "article:has(h3:contains('Visites')) .ajoute", text: /\AAjouté le #{Time.current.strftime('%-d/%m/%Y')}\z/
      assert_select "article:has(h3:contains('Opportunité en ligne')) .creneau strong", text: "Sans date limite"
    end

    test "tri par date de l'événement : en cours ou à venir d'abord, puis sans date, puis terminés" do
      creer_opportunite("Dans un mois", starts_on: Date.current + 30)
      creer_opportunite("Demain", starts_on: Date.current + 1)
      creer_opportunite("Terminé hier", starts_on: Date.current - 5, ends_on: Date.current - 1)
      creer_opportunite("En cours", starts_on: Date.current - 3, ends_on: Date.current + 60)
      get admin_galerie_path(tri: "evenement", statut: ""), headers: auth
      titres = css_select("article h3").map { |n| n.text.strip }
      ordre = ["En cours", "Demain", "Dans un mois"].map { |t| titres.index(t) }
      assert_equal ordre.sort, ordre, "du plus proche au plus lointain"
      assert_operator titres.index("Dans un mois"), :<, titres.index("Opportunité en ligne"), "les offres sans date viennent après"
      assert_operator titres.index("Opportunité en ligne"), :<, titres.index("Terminé hier") if titres.include?("Terminé hier")
    end

    test "filtre Période : en cours, à venir, terminés" do
      creer_opportunite("Dans un mois", starts_on: Date.current + 30)
      creer_opportunite("Terminé hier", starts_on: Date.current - 5, ends_on: Date.current - 1)
      creer_opportunite("En cours", starts_on: Date.current - 3, ends_on: Date.current + 60)
      get admin_galerie_path(periode: "a_venir", statut: ""), headers: auth
      assert_match "Dans un mois", texte
      assert_no_match(/En cours<|Terminé hier/, texte.gsub(/<option[^>]*>[^<]*<\/option>/, ""))
      get admin_galerie_path(periode: "termine", statut: "retire"), headers: auth
      assert_match "Terminé hier", texte
      get admin_galerie_path(periode: "en_cours", statut: ""), headers: auth
      assert_match "En cours", texte
      assert_match "Opportunité en ligne", texte, "une offre sans date est en cours"
      assert_no_match(/Portrait en ligne/, texte, "une Belle Histoire n'a pas de période")
    end

    test "écran du candidat : début, fin, heures et périodicité modifiables, reportés sur la fiche à la validation" do
      @propose.update!(summary: "Une phrase. Une autre.")
      get admin_veille_candidate_path(@propose), headers: auth
      %w[starts_on ends_on start_time end_time schedule_text].each { |champ| assert_select "fieldset.creneau [name=#{champ}]" }

      patch completer_admin_veille_candidate_path(@propose), headers: auth,
            params: { starts_on: "2026-12-05", ends_on: "2026-12-06", start_time: "10:00", end_time: "12:30", schedule_text: "chaque jour" }
      c = @propose.reload
      assert_equal [Date.new(2026, 12, 5), Date.new(2026, 12, 6)], [c.starts_on, c.ends_on]
      assert_equal ["10:00", "12:30"], [c.start_time, c.end_time].map { |t| t.strftime("%H:%M") }

      Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
      post valider_admin_veille_candidate_path(@propose), headers: auth
      opp = c.reload.opportunity
      assert_equal [Date.new(2026, 12, 6), "chaque jour"], [opp.ends_on, opp.schedule_text]
      assert_equal "10h - 12h30", opp.horaire_affiche
    end

    test "une fin avant le début est refusée" do
      patch completer_admin_veille_candidate_path(@propose), headers: auth, params: { starts_on: "2026-12-06", ends_on: "2026-12-05" }
      assert_match "Enregistrement refusé", flash[:alert]
      assert_nil @propose.reload.starts_on
    end

    test "répond 200 sur toutes les pages, tous préréglages et tris, avec des candidats de toutes origines et des heures" do
      Opportunity.create!(title: "Atelier du soir", description: "x", category: "decouvrir", city: "Nancy", location: "Nancy", latitude: 48.69, longitude: 6.18,
                          is_active: true, starts_on: Date.current + 3, start_time: "18:30", end_time: "20:00")
      30.times { |i| candidat("Agenda #{i}", origin: "agenda_nancy", enriched_at: Time.current, item_type: "opportunite", declic_category: "decouvrir", score: i,
                              starts_on: Date.current + i, start_time: [ "14h", "9h30", "14:00", nil ][i % 4], end_time: [ "16:00", nil ][i % 2]) }
      12.times { |i| candidat("JeVeuxAider #{i}", origin: "jeveuxaider", enriched_at: Time.current, item_type: "opportunite", declic_category: "benevolat", starts_on: Date.current, ends_on: Date.current + 40, schedule_text: "tous les samedis de 10h à 12h") }
      12.times { |i| candidat("Import #{i}", origin: "xlsx", enriched_at: Time.current, item_type: "opportunite").update_column(:declic_category, "rencontres") } # catégorie retirée
      12.times { |i| candidat("Non classé #{i}") }

      [ {}, { statut: "a_relire", tri: "score" }, { tri: "evenement" }, { statut: "non_trie" }, { periode: "a_venir" }, { periode: "en_cours" }, { type: "opportunite" } ].each do |filtres|
        premiere = get(admin_galerie_path(filtres), headers: auth) && response.status
        assert_equal 200, premiere, filtres.inspect
        pages = Galerie.new(filtres).pages
        (1..pages).each do |n|
          get admin_galerie_path(filtres.merge(page: n)), headers: auth
          assert_response :success, "#{filtres.inspect} page #{n}"
        end
      end
      get admin_galerie_path, headers: auth
      assert_select ".creneau", /14h/
    end

    # ---- Refonte d'après la maquette : compteurs, états de carte, menu ⋮, actions groupées ----

    def carte(titre) = "article:has(h3:contains('#{titre}'))"

    test "les compteurs du bandeau sont ceux de la base, un par statut réel, et chacun filtre la liste" do
      attendu = {
        "non_trie" => ::Veille::Candidate.where(status: "pending", enriched_at: nil).count,
        "propose" => ::Veille::Candidate.where(status: %w[pending retenu]).where.not(enriched_at: nil).count,
        "a_verifier" => ::Veille::Candidate.where(status: "a_verifier").count,
        "en_ligne" => Opportunity.publiques.count + Story.where(is_active: true).count,
        "ecarte" => ::Veille::Candidate.where(status: "ecarte").count,
        "retire" => (Opportunity.count - Opportunity.publiques.count) + Story.where(is_active: false).count
      }
      get admin_galerie_path, headers: auth
      GalerieHelper::COMPTEURS.each do |statut, libelle, _|
        assert_select "#compteurs-galerie a[href*='statut=#{statut}']", text: /#{libelle}\s*#{attendu[statut]}\z/
        assert_equal attendu[statut], ::Galerie.new.compteurs[statut][:total], statut
      end
      assert_select "#compteurs-galerie a.total strong", text: attendu.values.sum.to_s
      get admin_galerie_path(statut: "tous"), headers: auth
      assert_select "nav.pagination-admin .plage", text: "1 - #{attendu.values.sum} sur #{attendu.values.sum}", count: 2
    end

    test "le filtre de fiabilité ne garde que les candidats de cette fiabilité" do
      @propose.update!(reliability: "haute")
      get admin_galerie_path(fiabilite: "haute"), headers: auth
      assert_match "Proposé jardin", texte
      assert_no_match(/Non trié brut/, texte)
    end

    test "candidat non classé : Publier inactif, Classer en boutons sans OK ni JavaScript" do
      get admin_galerie_path, headers: auth
      assert_select carte("Non trié brut") do
        assert_select "form[action=?]", valider_admin_veille_candidate_path(@non_trie), 0
        assert_select "button[disabled]", text: /Publier/
        assert_select "details.menu-classer summary", text: /Classer/
        assert_select "form.choix-classement[action=?]", classer_admin_veille_candidate_path(@non_trie)
        assert_select "button[name=declic_category]", 6
        assert_select "input[type=submit][value=OK], select", 0
        assert_select "[onclick], [onchange], [onsubmit]", 0
      end
    end

    test "le menu ⋮ est un details/summary sans JavaScript, avec Modifier, À vérifier et Voir la source" do
      get admin_galerie_path, headers: auth
      assert_select carte("Proposé jardin") do
        assert_select "details.menu-plus > summary[aria-label='Autres actions']"
        assert_select "details.menu-plus a", text: "Modifier"
        assert_select "details.menu-plus form[action=?]", a_verifier_admin_veille_candidate_path(@propose)
        assert_select "details.menu-plus a[target=_blank]", text: /Voir la source/
        assert_select "details.menu-plus form.choix-classement"
        assert_select "[onclick]", 0
      end
      assert_select ".galerie-grille script, .galerie-grille [onclick]", 0 # rien d'exécutable dans les cartes
    end

    test "une carte écartée est estompée et propose Réactiver ; une fiche retirée aussi" do
      @opportunite.update!(is_active: false)
      get admin_galerie_path(statut: "ecarte"), headers: auth
      assert_select "#{carte('Écarté loisir')}.estompee"
      assert_select "#{carte('Écarté loisir')} form[action=?]", retenir_admin_veille_candidate_path(@ecarte), text: /Réactiver/
      get admin_galerie_path(statut: "retire"), headers: auth
      assert_select "#{carte('Opportunité en ligne')}.estompee form[action=?]", toggle_active_admin_opportunity_path(@opportunite), text: /Réactiver/
    end

    test "une fiche en ligne affiche Modifier et Retirer" do
      get admin_galerie_path(statut: "en_ligne"), headers: auth
      assert_select carte("Opportunité en ligne") do
        assert_select "a", text: "Modifier"
        assert_select "form[action=?]", toggle_active_admin_opportunity_path(@opportunite), text: "Retirer"
      end
    end

    test "le visuel est toujours l'illustration de repli : aucune image de source, une scène par catégorie" do
      get admin_galerie_path(statut: "tous"), headers: auth
      assert_select "article img", 0
      assert_select "article .visuel svg.illustration-repli", css_select("article.carte-galerie").size
      scenes = (Categorie::TOUTES.map(&:cle) + [ nil ]).map { |cle| ApplicationController.helpers.illustration_repli(cle) }
      assert_equal scenes.size, scenes.uniq.size
    end

    test "actions groupées : Publier saute les non classés et donne le décompte" do
      post admin_actions_galerie_path, params: { cles: [ @propose.then { |c| "candidate_#{c.id}" }, @non_trie.then { |c| "candidate_#{c.id}" } ], action_groupee: "publier", retour: "/admin/galerie?page=1" }, headers: auth
      assert_redirected_to "/admin/galerie?page=1"
      assert_equal "1 publiée, 1 ignorée : non classées", flash[:notice]
      assert @propose.reload.publie?
      assert @non_trie.reload.pending?
    end

    test "actions groupées : Écarter et Classer" do
      post admin_actions_galerie_path, params: { cles: [ @propose.then { |c| "candidate_#{c.id}" }, @verifier.then { |c| "candidate_#{c.id}" } ], action_groupee: "ecarter" }, headers: auth
      assert_equal "2 écartées", flash[:notice]
      assert [ @propose, @verifier ].all? { |c| c.reload.ecarte? }

      post admin_actions_galerie_path, params: { cles: [ @non_trie.then { |c| "candidate_#{c.id}" } ], action_groupee: "classer:opportunite:formation" }, headers: auth
      assert_equal "1 classée", flash[:notice]
      assert_equal %w[opportunite formation], @non_trie.reload.then { |c| [ c.item_type, c.declic_category ] }
      assert @non_trie.classement_manuel?
    end

    test "actions groupées : sans sélection, ou action inconnue, rien n'est modifié" do
      post admin_actions_galerie_path, params: { action_groupee: "publier" }, headers: auth
      assert_match "Coche d'abord", flash[:alert]
      post admin_actions_galerie_path, params: { cles: [ @propose.then { |c| "candidate_#{c.id}" } ], action_groupee: "supprimer" }, headers: auth
      assert_equal "Action groupée inconnue.", flash[:alert]
      assert @propose.reload.pending?
    end

    test "les cases sont des cases HTML standard liées au formulaire groupé, et « tout sélectionner » est un ajout Stimulus" do
      get admin_galerie_path, headers: auth
      assert_select "form#selection-groupee[method=post][action=?]", admin_actions_galerie_path
      assert_select "article input.case-carte[type=checkbox][form=selection-groupee][name='cles[]']", css_select("article.carte-galerie").size
      assert_select ".barre-outils[data-controller=galerie-selection] input[data-galerie-selection-target=toutes][hidden]"
    end
  end
end
