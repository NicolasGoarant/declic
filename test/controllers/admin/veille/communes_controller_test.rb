require "test_helper"

module Admin
  module Veille
    # Lecture manuelle des communes : liens seulement, « Retenir » crée un candidat ignoré des passes automatiques.
    class CommunesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user_avant, @pass_avant = ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]
        ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
      end

      teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @user_avant, @pass_avant }

      def auth
        { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("veille-test", "secret-de-test") }
      end

      def retenir(**params)
        post "/admin/veille/communes/retenir",
             params: { commune: "Ludres", titre: "Fête d'automne", url: "https://www.facebook.com/villedeludres/posts/123" }.merge(params),
             headers: auth
      end

      test "exige l'authentification" do
        get "/admin/veille/communes"
        assert_response :unauthorized
      end

      test "liste les communes sans flux exploitable, avec liens, et pas celles lues automatiquement" do
        assert_no_difference("::Veille::Candidate.count") { get "/admin/veille/communes", headers: auth }
        assert_response :success
        assert_select "td strong", text: "Ludres"
        assert_select "td strong", text: "Laxou"
        assert_select "td strong", text: "Pulnoy", count: 0
        assert_select "a[href=?][target=_blank]", "https://www.instagram.com/villedeludres/", text: "Instagram"
        assert_select "a[href=?]", "https://www.laxou.fr", text: "Site"
      end

      test "retenir crée un candidat manuel, hors des passes automatiques" do
        assert_difference("::Veille::Candidate.count", 1) { retenir }
        cand = ::Veille::Candidate.find_by!(origin: "commune_manuel")
        assert_redirected_to admin_veille_candidate_path(cand)
        assert_equal "Ludres", cand.commune
        assert_equal "retenu", cand.status
        assert_equal "opportunite", cand.item_type
        assert_equal "Fête d'automne", cand.title
        assert_not_includes ::Veille::Candidate.a_enrichir, cand
        assert_not_includes ::Veille::Candidate.hors_presse, cand
      end

      test "retenir deux fois le même lien ne crée qu'un candidat" do
        retenir
        assert_no_difference("::Veille::Candidate.count") { retenir }
      end

      test "retenir refuse un lien non http, un titre vide ou une commune étrangère" do
        assert_no_difference("::Veille::Candidate.count") do
          retenir(url: "javascript:alert(1)")
          retenir(titre: " ")
          retenir(commune: "Metz")
        end
        assert_redirected_to admin_veille_communes_path
        assert_match(/rien n'a été retenu/, flash[:alert])
      end

      test "la fiche d'un candidat retenu s'ouvre" do
        retenir
        cand = ::Veille::Candidate.find_by!(origin: "commune_manuel")
        get "/admin/veille/candidates/#{cand.id}", headers: auth
        assert_response :success
      end
    end
  end
end
