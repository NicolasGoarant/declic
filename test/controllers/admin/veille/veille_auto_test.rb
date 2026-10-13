require "test_helper"
require_relative "../../../services/veille/support"

module Admin
  module Veille
    # L'écran « Veille » : filtres, badge de fiabilité, Valider / Écarter / À vérifier.
    class VeilleAutoTest < ActionDispatch::IntegrationTest
      include VeilleSupport

      setup do
        @user_avant, @pass_avant = ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]
        ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
        Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
      end

      teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @user_avant, @pass_avant }

      def auth
        { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("veille-test", "secret-de-test") }
      end

      def texte = CGI.unescapeHTML(response.body)

      def enrichi(**attrs)
        candidat(**{ item_type: "opportunite", declic_category: "formation", commune: "Nancy", summary: "Un résumé reformulé.",
                   reliability: "haute", enriched_at: Time.current }.merge(attrs))
      end

      test "/admin/veille liste la file : lien d'origine, résumé reformulé, badge de fiabilité" do
        c = enrichi(title: "Forum de la formation", url: "https://exemple.fr/forum")

        get "/admin/veille", headers: auth

        assert_response :success
        assert_includes texte, "Forum de la formation"
        assert_includes texte, "Un résumé reformulé."
        assert_includes response.body, %(href="https://exemple.fr/forum")
        assert_includes response.body, "badge fiabilite haute"
        assert_includes texte, "Se former"
        assert_includes response.body, valider_admin_veille_candidate_path(c)
      end

      test "filtre par type, catégorie et source" do
        enrichi(title: "Opp formation", origin: "formation")
        enrichi(title: "Histoire écolo", item_type: "belle_histoire", declic_category: "ecologiser", origin: "presse")

        get "/admin/veille", params: { type: "belle_histoire" }, headers: auth
        assert_includes texte, "Histoire écolo"
        assert_not_includes texte, "Opp formation"

        get "/admin/veille", params: { categorie: "formation" }, headers: auth
        assert_includes texte, "Opp formation"
        assert_not_includes texte, "Histoire écolo"

        get "/admin/veille", params: { origine: "presse" }, headers: auth
        assert_includes texte, "Histoire écolo"
        assert_not_includes texte, "Opp formation"
      end

      test "filtre par date de collecte" do
        enrichi(title: "Ancien", fetched_at: Time.zone.local(2026, 1, 1), created_at: Time.zone.local(2026, 1, 1))
        enrichi(title: "Récent", fetched_at: Time.zone.local(2026, 10, 1))

        get "/admin/veille", params: { depuis: "2026-09-01" }, headers: auth
        assert_includes texte, "Récent"
        assert_not_includes texte, "Ancien"
      end

      test "Valider crée un brouillon hors ligne et rien d'autre" do
        c = enrichi(title: "Forum", url: "https://exemple.fr/forum")

        assert_difference -> { Opportunity.count }, 1 do
          post valider_admin_veille_candidate_path(c), headers: auth
        end

        assert_response :redirect
        assert_not Opportunity.order(:id).last.is_active
        assert_equal "publie", c.reload.status
      end

      test "Valider une belle histoire crée une Story inactive" do
        c = enrichi(item_type: "belle_histoire", draft_body: "Récit.\n\nSource : X\nAccord de la personne : à obtenir")
        assert_difference -> { Story.count }, 1 do
          post valider_admin_veille_candidate_path(c), headers: auth
        end
        assert_not Story.order(:id).last.is_active
      end

      test "Valider un élément incomplet explique ce qui manque et ne crée rien" do
        c = enrichi(commune: nil)
        assert_no_difference -> { Opportunity.count } do
          post valider_admin_veille_candidate_path(c), headers: auth
        end
        assert_includes flash[:alert], "Il manque la commune"
        assert_equal "pending", c.reload.status
      end

      test "Écarter et Marquer à vérifier changent le statut sans créer de fiche" do
        a = enrichi
        b = enrichi

        assert_no_difference -> { Opportunity.count + Story.count } do
          patch ecarter_admin_veille_candidate_path(a), headers: auth
          patch a_verifier_admin_veille_candidate_path(b), headers: auth
        end
        assert_equal "ecarte", a.reload.status
        assert_equal "a_verifier", b.reload.status

        get "/admin/veille", params: { status: "a_verifier" }, headers: auth
        assert_includes response.body, dom_id_for(b)
      end

      test "Marquer à vérifier en turbo stream remplace la ligne" do
        c = enrichi
        patch a_verifier_admin_veille_candidate_path(c), headers: auth.merge("Accept" => "text/vnd.turbo-stream.html")
        assert_response :success
        assert_includes response.body, "turbo-stream"
        assert_includes response.body, %(action="replace")
      end

      test "l'écran exige l'authentification admin" do
        get "/admin/veille"
        assert_response :unauthorized
      end

      def dom_id_for(c) = "veille_candidate_#{c.id}"
    end
  end
end
