require "test_helper"

module Admin
  module Veille
    class SourcesControllerTest < ActionDispatch::IntegrationTest
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

      def source(**attrs)
        ::Veille::Source.create!({
          name: "L'Est Républicain #{SecureRandom.hex(3)}",
          kind: "presse",
          url:  "https://estrepublicain.fr"
        }.merge(attrs))
      end

      test "liste les sources" do
        s = source

        get admin_veille_sources_path, headers: auth
        assert_response :success
        assert_match s.name, texte
        assert_match "presse", response.body
      end

      test "crée une source" do
        assert_difference -> { ::Veille::Source.count }, 1 do
          post admin_veille_sources_path,
               params:  { source: { name: "Nancy Mag", kind: "magazine_municipal",
                                    url: "https://nancy.fr/mag", active: "1" } },
               headers: auth
        end

        assert_redirected_to admin_veille_sources_path
        creee = ::Veille::Source.find_by(name: "Nancy Mag")
        assert_equal "magazine_municipal", creee.kind
        assert creee.active?
      end

      test "refuse un type hors de la liste et réaffiche le formulaire" do
        assert_no_difference -> { ::Veille::Source.count } do
          post admin_veille_sources_path,
               params:  { source: { name: "Flux RSS", kind: "rss", url: "https://x.fr" } },
               headers: auth
        end

        assert_response :unprocessable_entity
      end

      test "modifie une source" do
        s = source

        patch admin_veille_source_path(s),
              params:  { source: { name: s.name, kind: "media_public", url: s.url, active: "0" } },
              headers: auth

        assert_redirected_to admin_veille_sources_path
        s.reload
        assert_equal "media_public", s.kind
        assert_not s.active?
      end

      test "supprimer une source conserve ses candidats et les détache" do
        s = source
        c = ::Veille::Candidate.create!(url: "https://estrepublicain.fr/a", title: "T", source: s)

        assert_difference -> { ::Veille::Source.count }, -1 do
          assert_no_difference -> { ::Veille::Candidate.count } do
            delete admin_veille_source_path(s), headers: auth
          end
        end

        assert_nil c.reload.veille_source_id
      end

      test "le formulaire ne propose que les trois types prévus" do
        get new_admin_veille_source_path, headers: auth
        assert_response :success

        ::Veille::Source::KINDS.each { |k| assert_match %r{value="#{k}"}, response.body }
        assert_no_match %r{value="rss"}, response.body
        assert_no_match %r{value="ics"}, response.body
      end
    end
  end
end
