require "test_helper"
require "minitest/mock"
require_relative "../../../services/veille/support"
require_relative "../../../services/veille/fake_anthropic_client"

module Admin
  module Veille
    # Veille presse manuelle : liste à part, geste « Retenir », puis texte collé.
    class PresseControllerTest < ActionDispatch::IntegrationTest
      include VeilleSupport

      URL = "https://www.estrepublicain.fr/societe/un-article"

      setup do
        @user_avant, @pass_avant = ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]
        ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
        Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
        @lien = ::Veille::Connectors::Presse::Lien.new(titre: "Nancy. Un article", url: URL, flux: "L'Est Républicain",
                                                       publie_le: Time.zone.local(2026, 10, 31, 8))
      end

      teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @user_avant, @pass_avant }

      def auth
        { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("veille-test", "secret-de-test") }
      end

      def avec_flux(liens: [@lien], erreurs: {}, &)
        lecteur = Struct.new(:lister).new(::Veille::Connectors::Presse::Lecture.new(liens: liens, erreurs: erreurs))
        ::Veille::Connectors::Presse.stub(:new, lecteur, &)
      end

      def retenir(**params)
        post "/admin/veille/presse/retenir", params: { titre: "Nancy. Un article", url: URL, publie_le: "2026-10-31" }.merge(params), headers: auth
      end

      test "liste titres et liens sans rien créer en base" do
        assert_no_difference("::Veille::Candidate.count") do
          avec_flux { get "/admin/veille/presse", headers: auth }
        end
        assert_response :success
        assert_select "a[href=?][target=_blank]", URL, text: "Nancy. Un article"
      end

      test "signale le flux en erreur" do
        avec_flux(liens: [], erreurs: { "L'Est Républicain" => "HTTP 500" }) { get "/admin/veille/presse", headers: auth }
        assert_response :success
        assert_includes response.body, "HTTP 500"
      end

      test "la file de relecture ne montre pas la liste de veille" do
        get "/admin/veille", headers: auth
        assert_response :success
        assert_not_includes response.body, "Veille presse manuelle"
      end

      test "exige l'authentification" do
        get "/admin/veille/presse"
        assert_response :unauthorized
      end

      test "retenir crée un candidat sans contenu, que l'automatique ignore" do
        assert_difference("::Veille::Candidate.count", 1) { retenir }
        c = ::Veille::Candidate.find_by!(url: URL)
        assert_redirected_to "/admin/veille/candidates/#{c.id}"
        assert_equal %w[presse retenu belle_histoire], [c.origin, c.status, c.item_type]
        assert_equal Date.new(2026, 10, 31), c.published_on
        assert_nil c.full_text
        assert_nil c.excerpt
        assert_nil c.summary
        assert_not_includes ::Veille::Candidate.a_enrichir, c
        assert_not_includes ::Veille::Candidate.a_rediger, c
      end

      test "retenir deux fois ne crée pas de doublon" do
        retenir
        assert_no_difference("::Veille::Candidate.count") { retenir }
      end

      test "écarter mémorise l'URL seule, sans candidat, et l'article n'est plus proposé" do
        assert_no_difference("::Veille::Candidate.count") do
          assert_difference("::Veille::PresseEcartee.count", 1) do
            post "/admin/veille/presse/ecarter", params: { url: URL }, headers: auth
          end
        end
        assert_redirected_to "/admin/veille/presse"
        assert_equal [URL], ::Veille::PresseEcartee.pluck(:url)

        avec_flux { get "/admin/veille/presse", headers: auth }
        assert_select "a[href=?]", URL, count: 0
      end

      test "écarter deux fois ne crée pas de doublon" do
        post "/admin/veille/presse/ecarter", params: { url: URL }, headers: auth
        assert_no_difference("::Veille::PresseEcartee.count") do
          post "/admin/veille/presse/ecarter", params: { url: URL }, headers: auth
        end
      end

      test "écarter la sélection mémorise plusieurs URL d'un coup, sans candidat" do
        autre = "#{URL}-2"
        assert_no_difference("::Veille::Candidate.count") do
          assert_difference("::Veille::PresseEcartee.count", 2) do
            post "/admin/veille/presse/ecarter", params: { urls: [URL, autre, URL] }, headers: auth
          end
        end
        assert_redirected_to "/admin/veille/presse"
        assert_match "2 articles écartés", flash[:notice]
        assert_equal [URL, autre].sort, ::Veille::PresseEcartee.pluck(:url).sort
      end

      test "écarter la sélection : tout ou rien si un lien est étranger aux flux" do
        assert_no_difference("::Veille::PresseEcartee.count") do
          post "/admin/veille/presse/ecarter", params: { urls: [URL, "https://ailleurs.example/x"] }, headers: auth
        end
        assert flash[:alert].present?
      end

      test "écarter sans rien de sélectionné ne crée rien" do
        assert_no_difference("::Veille::PresseEcartee.count") { post "/admin/veille/presse/ecarter", headers: auth }
        assert_equal "Aucun article sélectionné.", flash[:alert]
      end

      test "la liste propose une case par article, le bouton de sélection et le tout sélectionner" do
        avec_flux { get "/admin/veille/presse", headers: auth }
        assert_select "input[type=checkbox][name='urls[]'][value=?][form=ecarter-selection]", URL
        assert_select "form#ecarter-selection button[disabled]", text: "Écarter la sélection"
        assert_select "input[type=checkbox][data-selection-target=tout]"
        assert_select "form[action=?] button", "/admin/veille/presse/ecarter", text: "Écarter" # le bouton de ligne reste
      end

      test "écarter refuse un lien hors des journaux de la veille" do
        assert_no_difference("::Veille::PresseEcartee.count") do
          post "/admin/veille/presse/ecarter", params: { url: "https://ailleurs.example/x" }, headers: auth
        end
        assert_redirected_to "/admin/veille/presse"
      end

      test "un autre article reste proposé quand le premier est écarté" do
        autre = ::Veille::Connectors::Presse::Lien.new(titre: "Autre", url: "#{URL}-2", flux: "L'Est Républicain", publie_le: Time.zone.local(2026, 10, 31, 9))
        ::Veille::PresseEcartee.create!(url: URL)
        avec_flux(liens: [@lien, autre]) { get "/admin/veille/presse", headers: auth }
        assert_select "a[href=?]", "#{URL}-2", text: "Autre"
        assert_select "a[href=?]", URL, count: 0
      end

      test "refuse un lien hors des journaux de la veille" do
        assert_no_difference("::Veille::Candidate.count") { retenir(url: "https://ailleurs.example/x") }
        assert_redirected_to "/admin/veille/presse"
      end

      test "du geste à la fiche : texte collé, commune et résumé saisis, fiche hors ligne" do
        retenir
        c = ::Veille::Candidate.find_by!(url: URL)
        reponse = { "brouillon" => "Une habitante de Nancy ouvre un atelier de couture et transmet son savoir.",
                    "personne" => "Une habitante", "champs_manquants" => [] }
        client = FakeAnthropicClient.new(text: reponse.to_json)

        ::Veille::Redaction::Brouillon.stub(:new, ::Veille::Redaction::Brouillon.new(client: client)) do
          post "/admin/veille/candidates/#{c.id}/rediger", params: { full_text: "Une habitante de Nancy ouvre un atelier de couture et transmet son savoir." }, headers: auth
        end
        assert_equal "redige", c.reload.draft_status

        post "/admin/veille/candidates/#{c.id}/valider", headers: auth
        assert_match(/Il manque/, flash[:alert])

        assert_no_difference("::Story.count") do
          patch "/admin/veille/candidates/#{c.id}/completer", params: { commune: "Nancy", summary: "Un atelier de couture ouvre à Nancy." }, headers: auth
        end
        assert_equal "retenu", c.reload.status, "la presse ne se publie pas à la saisie de la commune"

        post "/admin/veille/candidates/#{c.id}/valider", headers: auth
        assert_match(/accord de la personne/, flash[:alert])
        assert_equal 0, ::Story.where(veille_candidate_id: c.id).count

        patch "/admin/veille/candidates/#{c.id}/accord", params: { obtenu: "1" }, headers: auth
        assert_difference("::Story.active.count", 1) { post "/admin/veille/candidates/#{c.id}/valider", headers: auth }
        assert_nil c.reload.full_text, "le texte collé est effacé à la création de la fiche"
      end
    end
  end
end
