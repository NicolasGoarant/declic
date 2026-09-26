require "test_helper"
require "minitest/mock"

class PagesPubliquesTest < ActionDispatch::IntegrationTest
  setup do
    attrs = { description: "Texte", category: Opportunity::CATEGORIES.first, is_active: true,
              latitude: 48.69, longitude: 6.18, city: "Nancy", location: "54000 Nancy" }
    Opportunity.create!(attrs.merge(title: "Datée", starts_on: Date.current + 3, ends_on: Date.current + 5))
    Opportunity.create!(attrs.merge(title: "Permanente"))
    # Ancienne fiche : seules les chaînes start_date / end_date sont remplies (date_debut renvoie une String).
    Opportunity.create!(attrs.merge(title: "Ancienne")).update_columns(start_date: "2026-10-01", end_date: "2026-10-02")
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { true })
  end

  test "GET /labo/accueil avec une opportunité datée et une permanente" do
    DioramaTuiles.stub(:new, @tuiles) { get labo_accueil_url }
    assert_response :success
  end

  test "GET / avec une opportunité datée et une permanente" do
    get root_url
    assert_response :success
  end

  test "GET /labo/diorama" do
    DioramaTuiles.stub(:new, @tuiles) { get labo_diorama_url }
    assert_response :success
  end
end
