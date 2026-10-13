require "test_helper"
require "minitest/mock"

module Admin
  module Veille
    class CandidatesControllerTest < ActionDispatch::IntegrationTest
      IDENTIFIANTS = { user: "veille-test", pass: "secret-de-test" }.freeze

      setup do
        @user_avant = ENV["ADMIN_USERNAME"]
        @pass_avant = ENV["ADMIN_PASSWORD"]
        ENV["ADMIN_USERNAME"] = IDENTIFIANTS[:user]
        ENV["ADMIN_PASSWORD"] = IDENTIFIANTS[:pass]
      end

      teardown do
        ENV["ADMIN_USERNAME"] = @user_avant
        ENV["ADMIN_PASSWORD"] = @pass_avant
      end

      def auth
        { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic
            .encode_credentials(IDENTIFIANTS[:user], IDENTIFIANTS[:pass]) }
      end

      # Les apostrophes françaises sont échappées en &#39; dans le HTML rendu.
      def texte = CGI.unescapeHTML(response.body)

      def candidat(**attrs)
        ::Veille::Candidate.create!({
          url:       "https://exemple.fr/a-#{SecureRandom.hex(4)}",
          title:     "Le jardin partagé de Laxou",
          excerpt:   "Trente familles cultivent 800 m².",
          full_text: "Le texte intégral de l'article.",
          category:  "belle_histoire",
          score:     87,
          reason:    "Personne nommée et initiative concrète.",
          qualified_at: Time.current
        }.merge(attrs))
      end

      # Doublure de Veille::Drafter.
      class FakeDrafter
        BROUILLON = {
          "titre" => "Le jardin qui a remplacé le parking",
          "personne" => "Sylvie Mangin",
          "commune" => "Laxou",
          "resume" => "Une phrase. Deux phrases. Trois phrases.",
          "theme" => "jardin partagé",
          "champs_manquants" => ["date exacte d'ouverture"]
        }.freeze

        def initialize(raise_with: nil) = @raise_with = raise_with
        def draft(_candidate)
          raise @raise_with if @raise_with
          BROUILLON
        end
      end

      # ----------------------------------------------------------------
      # Authentification — on réutilise celle d'Admin::BaseController.
      # ----------------------------------------------------------------
      test "l'interface est fermée sans identifiants" do
        get admin_veille_candidates_path
        assert_response :unauthorized
      end

      test "les sources aussi sont fermées" do
        get admin_veille_sources_path
        assert_response :unauthorized
      end

      # ----------------------------------------------------------------
      # index — la file de tri
      # ----------------------------------------------------------------
      test "la file liste les candidats en attente, meilleur score d'abord" do
        faible = candidat(score: 20, title: "Compte rendu du conseil")
        fort   = candidat(score: 95, title: "Le potager de Madame Durand")

        get admin_veille_candidates_path, headers: auth
        assert_response :success

        assert_match fort.title, response.body
        assert_match faible.title, response.body
        assert_operator response.body.index(fort.title), :<,
                        response.body.index(faible.title),
                        "le meilleur score doit apparaître en premier"
      end

      test "la file affiche titre, chapeau, source, date, score et motif" do
        c = candidat(published_on: Date.new(2026, 3, 14))

        get admin_veille_candidates_path, headers: auth

        assert_match c.title, response.body
        assert_match "Trente familles cultivent", response.body
        assert_match "exemple.fr", response.body
        assert_match "14/03/2026", response.body
        assert_match "87", response.body
        assert_match "Personne nommée et initiative concrète.", response.body
      end

      test "le lien vers l'article s'ouvre dans un nouvel onglet" do
        c = candidat

        get admin_veille_candidates_path, headers: auth
        lien = response.body[/<a\b[^>]*href="#{Regexp.escape(c.url)}"[^>]*>/]
        assert lien, "le lien vers l'article doit être présent"
        assert_match 'target="_blank"', lien
        assert_match 'rel="noopener noreferrer"', lien
      end

      test "les candidats déjà tranchés ne sont pas dans la file" do
        retenu = candidat(status: "retenu", title: "Déjà retenu")

        get admin_veille_candidates_path, headers: auth
        assert_no_match retenu.title, response.body

        get admin_veille_candidates_path(status: "retenu"), headers: auth
        assert_match retenu.title, response.body
      end

      # ----------------------------------------------------------------
      # Retenir / Écarter en Turbo Stream
      # ----------------------------------------------------------------
      test "Retenir renvoie un Turbo Stream qui retire la ligne de la file" do
        c = candidat

        patch retenir_admin_veille_candidate_path(c),
              headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")

        assert_response :success
        assert_equal "text/vnd.turbo-stream.html", response.media_type
        assert_match %r{<turbo-stream action="remove" target="veille_candidate_#{c.id}">}, response.body
        assert_equal "retenu", c.reload.status
      end

      test "Écarter retire aussi la ligne et met à jour les compteurs" do
        c = candidat

        patch ecarter_admin_veille_candidate_path(c),
              headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")

        assert_match %r{action="remove" target="veille_candidate_#{c.id}"}, response.body
        assert_match %r{<turbo-stream action="update" target="compteurs">}, response.body
        assert_equal "ecarte", c.reload.status
      end

      test "sans Turbo, Retenir redirige vers la file" do
        c = candidat

        patch retenir_admin_veille_candidate_path(c), headers: auth
        assert_redirected_to admin_veille_candidates_path
        assert_equal "retenu", c.reload.status
      end

      # ----------------------------------------------------------------
      # show — écran à deux colonnes
      # ----------------------------------------------------------------
      test "l'écran du candidat retenu montre la source et la zone de texte" do
        c = candidat(status: "retenu")

        get admin_veille_candidate_path(c), headers: auth
        assert_response :success

        assert_match c.url, response.body
        assert_match "Personne nommée et initiative concrète.", response.body
        assert_match %r{<textarea[^>]+name="full_text"}, response.body
        assert_match "Rédiger", response.body
        assert_match %r{id="brouillon"}, response.body
      end

      # ----------------------------------------------------------------
      # rediger — passe B
      # ----------------------------------------------------------------
      test "Rédiger renvoie le brouillon dans un formulaire éditable par Turbo Stream" do
        c = candidat(status: "retenu")

        ::Veille::Drafter.stub(:new, FakeDrafter.new) do
          post rediger_admin_veille_candidate_path(c),
               params:  { full_text: "Le texte collé par l'admin." },
               headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
        end

        assert_response :success
        assert_match %r{<turbo-stream action="update" target="brouillon">}, response.body
        assert_match "Le jardin qui a remplacé le parking", response.body
        assert_match "Sylvie Mangin", response.body
        assert_match %r{name="draft\[resume\]"}, response.body
        assert_match "date exacte d'ouverture", texte, "les champs manquants sont signalés"
        assert_equal "Le texte collé par l'admin.", c.reload.full_text
      end

      test "une panne API affiche un message et laisse le candidat intact" do
        c = candidat(status: "retenu")
        panne = FakeDrafter.new(raise_with: AnthropicClient::ConnectionError.new("timeout"))

        ::Veille::Drafter.stub(:new, panne) do
          post rediger_admin_veille_candidate_path(c),
               params:  { full_text: "Texte." },
               headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
        end

        assert_response :unprocessable_entity
        assert_match "n'a pas répondu à temps", texte
        assert_equal "retenu", c.reload.status
      end

      test "une réponse illisible affiche un message dédié" do
        c = candidat(status: "retenu")
        cassee = FakeDrafter.new(raise_with: ::Veille::AiPass::ParseError.new("pas de JSON"))

        ::Veille::Drafter.stub(:new, cassee) do
          post rediger_admin_veille_candidate_path(c),
               params:  { full_text: "Texte." },
               headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
        end

        assert_response :unprocessable_entity
        assert_match "réponse inexploitable", texte
      end

      # ----------------------------------------------------------------
      # publier — création de la fiche et purge du tampon
      # ----------------------------------------------------------------
      test "Publier crée la fiche en brouillon, la relie au candidat et vide full_text" do
        c = candidat(status: "retenu", published_on: Date.new(2026, 3, 14))
        Geocoder::Lookup::Test.add_stub("Laxou", [{ "latitude" => 48.6936, "longitude" => 6.1496, "address" => "Laxou" }])

        assert_difference -> { Story.count }, 1 do
          post publier_admin_veille_candidate_path(c),
               params:  { draft: FakeDrafter::BROUILLON.slice("titre", "personne", "commune", "resume", "theme") },
               headers: auth
        end

        story = Story.find_by(veille_candidate_id: c.id)
        assert_redirected_to admin_veille_candidates_path

        assert_equal "Le jardin qui a remplacé le parking", story.title
        assert_equal "Une phrase. Deux phrases. Trois phrases.", story.chapo
        assert_equal "Laxou", story.location
        assert_equal "jardin partagé", story.tags
        assert_equal Date.new(2026, 3, 14), story.happened_on
        assert_equal c.url, story.source_url
        assert_not story.is_active, "la fiche est relue avant mise en ligne"
        assert_match "[Source originale](#{c.url})", story.body

        c.reload
        assert_nil c.full_text, "le tampon est effacé dès la création de la fiche"
        assert_equal "publie", c.status
      end

      test "un titre vide dans le formulaire retombe sur celui du candidat" do
        c = candidat(status: "retenu")
        Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])

        post publier_admin_veille_candidate_path(c),
             params:  { draft: { titre: "", commune: "Nancy", resume: "Un résumé." } },
             headers: auth

        assert_equal c.title, Story.find_by(veille_candidate_id: c.id).title
      end
    end
  end
end
