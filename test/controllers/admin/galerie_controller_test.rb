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
      %w[s-en_ligne s-propose s-a_verifier s-non_trie].each { |classe| assert_select "article .badge.#{classe}" }
      assert_select "article .badge.t-opportunite"
      assert_select "article .badge.t-belle_histoire"
      assert_match "IA 77", texte
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
      assert_select "a[href=?]", story_path(@histoire), text: "Voir sur le site"
      assert_select "form[action=?]", valider_admin_veille_candidate_path(@propose)
      assert_select "form[action=?]", ecarter_admin_veille_candidate_path(@propose)
      assert_select "a[href=?]", admin_veille_candidate_path(@propose, anchor: "apercu"), text: "Aperçu"
      assert_select "a[href=?]", admin_veille_candidate_path(@propose), text: "Modifier"
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
  end
end
