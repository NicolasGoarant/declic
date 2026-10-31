require "test_helper"
require "minitest/mock"
require_relative "../../../services/veille/fake_anthropic_client"

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
          score:     87,
          reason:    "Personne nommée et initiative concrète."
        }.merge(attrs))
      end

      RECIT = "Elle a rouvert la porte d'un ancien atelier de couture, au cœur du quartier, après des années de silence. " \
              "Depuis, des voisins viennent y apprendre les gestes de la réparation, ceux que leurs grands-mères connaissaient. " \
              "Chacun repart avec un vêtement remis en état et le sentiment d'avoir retrouvé un savoir-faire. " \
              "Autour de la machine à coudre, les conversations se nouent et le quartier se redécouvre."

      # Substitue au Brouillon web un vrai Brouillon branché sur un faux client Anthropic.
      def avec_ia(text: nil, raise_with: nil, usage: { "input_tokens" => 500, "output_tokens" => 300 })
        text ||= { brouillon: RECIT, personne: "Sylvie Mangin", champs_manquants: ["date exacte d'ouverture"] }.to_json
        client = FakeAnthropicClient.new(text: text, raise_with: raise_with, usage: usage)
        brouillon = ::Veille::Redaction::Brouillon.new(client: client, profil: :web)
        ::Veille::Redaction::Brouillon.stub(:new, brouillon) { yield client }
      end

      def turbo = auth.merge("Accept" => "text/vnd.turbo-stream.html")

      def histoire(**attrs)
        candidat(**{ item_type: "belle_histoire", origin: "presse", commune: "Laxou", summary: "Un jardin partagé naît à Laxou.",
                   status: "retenu", published_on: Date.new(2026, 3, 14) }.merge(attrs))
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
      # rediger — Redaction::Brouillon
      # ----------------------------------------------------------------
      test "Rédiger enregistre le récit, le contrôle et le renvoie éditable par Turbo Stream" do
        c = histoire

        avec_ia do
          post rediger_admin_veille_candidate_path(c), params: { full_text: "Le texte collé par l'admin." }, headers: turbo
        end

        assert_response :success
        assert_match %r{<turbo-stream action="update" target="brouillon">}, response.body
        assert_match "Elle a rouvert la porte", texte
        assert_match %r{<textarea[^>]+name="recit"}, response.body
        assert_match "date exacte d'ouverture", texte, "les champs manquants sont signalés"
        assert_match "Accord de la personne obtenu", texte
        assert_match "Coût IA de ce candidat", texte
        c.reload
        assert_equal "Le texte collé par l'admin.", c.full_text
        assert_equal "redige", c.draft_status
        assert_includes c.draft_body, "Accord de la personne : à obtenir"
        assert_equal 1, c.appels_ia.count
      end

      test "sans texte collé, Rédiger part du résumé" do
        c = histoire(full_text: nil)
        avec_ia do |client|
          post rediger_admin_veille_candidate_path(c), headers: turbo
          assert_includes client.user_content, "Résumé : Un jardin partagé naît à Laxou."
        end
        assert_response :success
      end

      test "un brouillon refusé par les contrôles est montré avec ses points bloquants, et Valider est désactivé" do
        c = histoire
        mauvais = { brouillon: "Venez à 20h30 au jardin partagé.", personne: "X", champs_manquants: [] }.to_json

        avec_ia(text: mauvais) { post rediger_admin_veille_candidate_path(c), params: { full_text: "t" }, headers: turbo }

        assert_response :success
        assert_match "Points bloquants", texte
        assert_match "Un horaire figure", texte
        assert_match %r{<button[^>]+disabled[^>]*>Valider}, response.body
        assert_equal "a_verifier", c.reload.draft_status
      end

      test "une panne API affiche un message et laisse le candidat intact" do
        c = histoire

        avec_ia(raise_with: AnthropicClient::ConnectionError.new("timeout")) do
          post rediger_admin_veille_candidate_path(c), params: { full_text: "Texte." }, headers: turbo
        end

        assert_response :unprocessable_entity
        assert_match "n'a pas répondu à temps", texte
        assert_equal "retenu", c.reload.status
        assert_equal "a_reprendre", c.draft_status
      end

      test "une réponse illisible affiche un message dédié" do
        c = histoire
        avec_ia(text: "désolé") { post rediger_admin_veille_candidate_path(c), params: { full_text: "Texte." }, headers: turbo }

        assert_response :unprocessable_entity
        assert_match "réponse inexploitable", texte
      end

      test "plafond mensuel atteint : message explicite, aucun appel" do
        ::Veille::AppelIa.create!(passe: "redaction", modele: "m", statut: "ok", cout_usd: 15)
        c = histoire

        avec_ia do |client|
          post rediger_admin_veille_candidate_path(c), params: { full_text: "Texte." }, headers: turbo
          assert_empty client.calls
        end

        assert_response :unprocessable_entity
        assert_match "Plafond mensuel atteint", texte
      end

      test "rien à rédiger sans résumé ni texte" do
        c = histoire(summary: nil, full_text: nil)
        avec_ia { post rediger_admin_veille_candidate_path(c), headers: turbo }
        assert_response :unprocessable_entity
        assert_match "Rien à rédiger", texte
      end

      # ----------------------------------------------------------------
      # enregistrer_brouillon et accord
      # ----------------------------------------------------------------
      test "enregistrer_brouillon recontrôle le récit corrigé et repose les mentions" do
        c = histoire(draft_body: "Ancien.\n\nSource : X — u\nAccord de la personne : à obtenir", draft_status: "a_verifier")

        patch enregistrer_brouillon_admin_veille_candidate_path(c), params: { recit: RECIT }, headers: turbo

        assert_response :success
        c.reload
        assert_equal "redige", c.draft_status
        assert_equal RECIT, ::Veille::Redaction::Brouillon.sans_mentions(c.draft_body)
        assert_match(/Source : .* — #{Regexp.escape(c.url)}\nAccord de la personne : à obtenir\z/, c.draft_body)
      end

      test "enregistrer_brouillon signale un récit corrigé qui enfreint la règle" do
        c = histoire(draft_body: "Récit.\n\nSource : X — u\nAccord de la personne : à obtenir")

        patch enregistrer_brouillon_admin_veille_candidate_path(c), params: { recit: "Inscrivez-vous au 03 83 12 34 56." }, headers: turbo

        assert_equal "a_verifier", c.reload.draft_status
        assert_includes c.draft_controles["bloquants"].map { |b| b["code"] }, "appel_a_agir"
        assert_includes c.draft_controles["bloquants"].map { |b| b["code"] }, "contact"
      end

      test "enregistrer_brouillon refuse un récit vide" do
        c = histoire(draft_body: "Récit.\n\nSource : X — u\nAccord de la personne : à obtenir")
        patch enregistrer_brouillon_admin_veille_candidate_path(c), params: { recit: "  " }, headers: turbo
        assert_response :unprocessable_entity
        assert_includes c.reload.draft_body, "Récit."
      end

      test "accord : daté, reporté dans la mention du récit, et retirable" do
        c = histoire(draft_body: "Récit.\n\nSource : X — u\nAccord de la personne : à obtenir")

        patch accord_admin_veille_candidate_path(c), params: { obtenu: "1" }, headers: turbo
        assert_response :success
        c.reload
        assert_not_nil c.accord_obtenu_at
        assert_match(/Accord de la personne : obtenu le \d{2}\/\d{2}\/\d{4}\z/, c.draft_body)

        patch accord_admin_veille_candidate_path(c), params: { obtenu: "0" }, headers: turbo
        c.reload
        assert_nil c.accord_obtenu_at
        assert_match(/Accord de la personne : à obtenir\z/, c.draft_body)
      end

      # ----------------------------------------------------------------
      # Valider — seul chemin vers une Story
      # ----------------------------------------------------------------
      test "publier n'existe plus : Valider est le seul chemin vers une Story" do
        assert_raises(NoMethodError) { publier_admin_veille_candidate_path(1) }
        assert_not_includes ::Admin::Veille::CandidatesController.action_methods, "publier"
      end

      test "Valider crée la Story inactive avec le récit relu, la date d'accord et la purge du tampon" do
        c = histoire(full_text: "Tampon.", commune: "Laxou", draft_status: "redige", accord_obtenu_at: Time.zone.local(2026, 11, 3),
                     draft_body: "#{RECIT}\n\nSource : Presse — u\nAccord de la personne : obtenu le 03/11/2026")
        Geocoder::Lookup::Test.add_stub("Laxou", [{ "latitude" => 48.6936, "longitude" => 6.1496, "address" => "Laxou" }])

        assert_difference -> { Story.count }, 1 do
          post valider_admin_veille_candidate_path(c), headers: auth
        end

        story = Story.find_by!(veille_candidate_id: c.id)
        assert_not story.is_active
        assert_equal Time.zone.local(2026, 11, 3), story.accord_obtenu_at
        assert_includes story.body, "Elle a rouvert la porte"
        assert_equal c.url, story.source_url
        assert_nil c.reload.full_text
        assert_equal "publie", c.status
      end

      test "Valider refuse un récit dont les contrôles sont bloquants" do
        c = histoire(draft_status: "a_verifier", draft_body: "Venez !\n\nSource : X — u\nAccord de la personne : à obtenir")
        assert_no_difference -> { Story.count } do
          post valider_admin_veille_candidate_path(c), headers: auth
        end
        assert_match "points bloquants", flash[:alert]
        assert_equal "retenu", c.reload.status
      end

      test "l'écran du candidat montre le brouillon automatique (jusque-là invisible)" do
        c = histoire(draft_status: "redige", draft_manques: ["commune"],
                     draft_body: "Un récit lisible.\n\nSource : X — u\nAccord de la personne : à obtenir")
        get admin_veille_candidate_path(c), headers: auth
        assert_match "Un récit lisible.", texte
        assert_match "commune", texte
        assert_match %r{class="manquants"}, response.body
      end

      test "la file renvoie vers l'écran de relecture pour une belle histoire, et garde Valider pour une opportunité" do
        h = histoire(status: "pending", title: "Histoire en file")
        o = candidat(item_type: "opportunite", status: "pending", title: "Opportunité en file", summary: "R.", commune: "Nancy")

        get admin_veille_candidates_path, headers: auth
        assert_match "Relire le récit", texte
        assert_match %r{action="#{Regexp.escape(valider_admin_veille_candidate_path(o))}"}, response.body
        assert_no_match %r{action="#{Regexp.escape(valider_admin_veille_candidate_path(h))}"}, response.body
      end
    end
  end
end
