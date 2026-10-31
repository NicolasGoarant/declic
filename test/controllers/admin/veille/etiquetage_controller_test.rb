require "test_helper"

module Admin
  module Veille
    class EtiquetageControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user_avant, @pass_avant = ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"]
        ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
      end

      teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @user_avant, @pass_avant }

      def auth
        { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("veille-test", "secret-de-test") }
      end

      def stream = auth.merge("ACCEPT" => "text/vnd.turbo-stream.html")

      test "affiche les 30 cas avec trois boutons, sans la décision de la v4" do
        get "/admin/veille/etiquetage", headers: auth
        assert_response :success
        assert_select "section.etiq", 30
        assert_select "section#C10 button[name=avis]", 3
        assert_select "section#C10 input[name=commentaire]", 1
        ::Veille::Etiquetage.cas.each { |c| assert_not_includes response.body, c.v4["motif"].to_s if c.v4["motif"] }
        assert_not_includes response.body, "Gardé"
        assert_not_includes response.body, "faux positif"
      end

      test "la presse n'a que le titre et le lien" do
        get "/admin/veille/etiquetage", headers: auth
        assert_select "section#C171 a[href=?]", ::Veille::Etiquetage.trouver("C171").lien
        assert_not_includes response.body, "Le succès est toujours au rendez-vous"
      end

      test "un clic enregistre l'avis et le commentaire, sans rechargement" do
        patch "/admin/veille/etiquetage/C10", params: { avis: "ecarter", commentaire: " trop savant " }, headers: stream
        assert_response :success
        assert_equal "text/vnd.turbo-stream.html", response.media_type
        assert_includes response.body, "boutons_C10"
        assert_includes response.body, "1 / 30"
        e = ::Veille::Etiquette.find_by!(ref: "C10")
        assert_equal %w[ecarter trop\ savant], [e.avis, e.commentaire]
      end

      test "un second clic change l'avis sans doublon, et le commentaire seul garde l'avis" do
        patch "/admin/veille/etiquetage/C10", params: { avis: "garder" }, headers: stream
        patch "/admin/veille/etiquetage/C10", params: { avis: "douteux" }, headers: stream
        patch "/admin/veille/etiquetage/C10", params: { commentaire: "à revoir" }, headers: stream
        assert_equal 1, ::Veille::Etiquette.where(ref: "C10").count
        e = ::Veille::Etiquette.find_by!(ref: "C10")
        assert_equal ["douteux", "à revoir"], [e.avis, e.commentaire]
      end

      test "un commentaire sans avis ne compte pas comme étiqueté" do
        patch "/admin/veille/etiquetage/C10", params: { commentaire: "je reviendrai" }, headers: stream
        assert_includes response.body, "0 / 30"
      end

      test "refuse un avis inconnu et un cas hors du jeu" do
        patch "/admin/veille/etiquetage/C10", params: { avis: "peut-etre" }, headers: stream
        assert_response :unprocessable_entity
        patch "/admin/veille/etiquetage/C999", params: { avis: "garder" }, headers: stream
        assert_response :not_found
        assert_equal 0, ::Veille::Etiquette.count
      end

      test "ne touche ni aux candidats ni à la file de relecture, et n'appelle pas l'IA" do
        c = ::Veille::Candidate.create!(url: "https://exemple.fr/c10", title: "Un candidat")
        assert_no_difference(["::Veille::AppelIa.count", "::Story.count", "::Opportunity.count"]) do
          patch "/admin/veille/etiquetage/C10", params: { avis: "ecarter" }, headers: stream
        end
        assert_equal "pending", c.reload.status
        get "/admin/veille", headers: auth
        assert_not_includes response.body, "1 / 30"
      end

      test "sans JavaScript, le clic revient à la page" do
        patch "/admin/veille/etiquetage/C10", params: { avis: "garder" }, headers: auth
        assert_redirected_to "/admin/veille/etiquetage#C10"
      end

      test "exige l'authentification" do
        get "/admin/veille/etiquetage"
        assert_response :unauthorized
        patch "/admin/veille/etiquetage/C10", params: { avis: "garder" }
        assert_response :unauthorized
      end
    end
  end
end
