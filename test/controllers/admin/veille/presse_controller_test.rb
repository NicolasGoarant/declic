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

        patch "/admin/veille/candidates/#{c.id}/completer", params: { commune: "Nancy", summary: "Un atelier de couture ouvre à Nancy." }, headers: auth
        assert_difference("::Story.count", 1) { post "/admin/veille/candidates/#{c.id}/valider", headers: auth }
        assert_nil c.reload.full_text, "le texte collé est effacé à la création de la fiche"
      end
    end
  end
end
