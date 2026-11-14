require "test_helper"
require "minitest/mock"

class AdminAccesTest < ActionDispatch::IntegrationTest
  CLES = %w[ADMIN_USERNAME ADMIN_PASSWORD ADMIN_SANS_MOT_DE_PASSE].freeze
  setup { @env = ENV.to_h.slice(*CLES) }
  teardown do
    CLES.each { |cle| ENV[cle] = @env[cle] }
  end

  def en_env(nom, &bloc)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(nom), &bloc)
  end

  def codes(chemins)
    chemins.map { |c| get(c); response.status }
  end

  CHEMINS = %w[/admin/galerie /admin/veille].freeze

  def identifiants(user, pass)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, pass) }
  end

  test "403 si ADMIN_USERNAME est absent, même avec des identifiants" do
    ENV.delete("ADMIN_USERNAME")
    ENV["ADMIN_PASSWORD"] = "secret"
    get admin_root_url, headers: identifiants("", "secret")
    assert_response :forbidden
  end

  test "403 si ADMIN_PASSWORD est vide, même avec des identifiants" do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = ""
    get admin_root_url, headers: identifiants("admin", "")
    assert_response :forbidden
  end

  test "401 avec un mauvais mot de passe, accès avec le bon" do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    get admin_root_url, headers: identifiants("admin", "faux")
    assert_response :unauthorized
    get admin_root_url, headers: identifiants("admin", "secret")
    assert_response :success
  end

  test "test : 401 sans identifiants, même avec ADMIN_SANS_MOT_DE_PASSE=1" do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    ENV["ADMIN_SANS_MOT_DE_PASSE"] = "1"
    assert_equal [ 401, 401 ], codes(CHEMINS)
  end

  test "développement : 401 sans la variable, accès libre avec elle à 1" do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    en_env("development") do
      ENV.delete("ADMIN_SANS_MOT_DE_PASSE")
      assert_equal [ 401, 401 ], codes(CHEMINS)
      ENV["ADMIN_SANS_MOT_DE_PASSE"] = "0"
      assert_equal [ 401, 401 ], codes(CHEMINS)
      ENV["ADMIN_SANS_MOT_DE_PASSE"] = "1"
      assert_equal [ 200, 200 ], codes(CHEMINS)
    end
  end

  test "production avec la variable à 1 : 401" do
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    ENV["ADMIN_SANS_MOT_DE_PASSE"] = "1"
    en_env("production") { assert_equal [ 401, 401 ], codes(CHEMINS) }
  end
end
