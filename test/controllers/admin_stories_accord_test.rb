require "test_helper"

class AdminStoriesAccordTest < ActionDispatch::IntegrationTest
  setup do
    @env = ENV.to_h.slice("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    @headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }
    Story.delete_all
    candidat = Veille::Candidate.create!(url: "https://exemple.fr/#{SecureRandom.hex(3)}", title: "Un portrait")
    @veille = Story.create!(title: "Portrait de la veille", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: candidat)
    @main   = Story.create!(title: "Histoire à la main", location: "Nancy", latitude: 48.69, longitude: 6.18)
  end

  teardown { %w[ADMIN_USERNAME ADMIN_PASSWORD].each { |cle| ENV[cle] = @env[cle] } }

  test "la bascule en ligne d'une fiche sans accord est refusée avec la raison" do
    patch toggle_active_admin_story_path(@veille), headers: @headers
    assert_not @veille.reload.is_active
    assert_includes flash[:alert], "accord de la personne"
  end

  test "le formulaire d'édition propose la case d'accord pour une fiche de la veille seulement" do
    get edit_admin_story_path(@veille), headers: @headers
    assert_includes response.body, "Accord de la personne obtenu"

    get edit_admin_story_path(@main), headers: @headers
    assert_not_includes response.body, "Accord de la personne obtenu"
  end

  test "cocher l'accord puis publier depuis le formulaire" do
    patch admin_story_path(@veille), params: { story: { accord_obtenu: "1", is_active: "1" } }, headers: @headers
    assert @veille.reload.is_active
    assert_not_nil @veille.accord_obtenu_at
  end
end
