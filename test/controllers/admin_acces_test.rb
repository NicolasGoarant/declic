require "test_helper"

class AdminAccesTest < ActionDispatch::IntegrationTest
  setup { @env = ENV.to_h.slice("ADMIN_USERNAME", "ADMIN_PASSWORD") }
  teardown do
    %w[ADMIN_USERNAME ADMIN_PASSWORD].each { |cle| ENV[cle] = @env[cle] }
  end

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
end
