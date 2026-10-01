require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "l'ancienne accueil vit sous /pourquoi-declic" do
    get pourquoi_declic_url
    assert_response :success
    assert_equal "/pourquoi-declic", pourquoi_declic_path
    assert_select "h1", /Change ta vie/i
  end
end
