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

  test "GET / (nouvelle accueil) avec une opportunité datée et une permanente" do
    DioramaTuiles.stub(:new, @tuiles) { get root_url }
    assert_response :success
    assert_select ".acc-ecran#carte"
    assert_nil response.headers["X-Robots-Tag"], "la racine doit rester indexable"
  end

  test "GET /labo/accueil : redirection permanente vers la racine, query string conservée" do
    get "/labo/accueil"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/"

    get "/labo/accueil?favoris=1"
    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/?favoris=1"
  end

  test "la racine et /pourquoi-declic sont deux pages distinctes" do
    DioramaTuiles.stub(:new, @tuiles) { get root_url }
    assert_select ".acc-ecran"
    get pourquoi_declic_url
    assert_select ".acc-ecran", 0
  end

  test "la navbar de l'ancienne accueil renvoie ses ancres vers /pourquoi-declic, le logo vers la racine" do
    get pourquoi_declic_url
    assert_select "header a[href=?]", "/"
    assert_select "header nav a[href=?]", "/pourquoi-declic#parcours"
    assert_select "header nav a", text: "Explorer", count: 0
    assert_select "header nav a[href=?]", philosophie_path, text: "Pourquoi Déclic ?"
  end

  test "GET /labo/diorama" do
    DioramaTuiles.stub(:new, @tuiles) { get labo_diorama_url }
    assert_response :success
  end

  test "GET /philosophie : page « Pourquoi Déclic ? » refondue" do
    Rails.cache.delete("pourquoi/chiffres")
    get philosophie_url
    assert_response :success
    assert_select "h1", /Pourquoi/
    assert_select ".pq-chiffres strong", text: Opportunity.active.count.to_s
    assert_select "a.pq-carte[href=?]", root_path
    assert_select "img[alt=?]", "Portrait de Nicolas Goarant, fondateur de Déclic"
    assert_select "meta[property='og:image'][content*='place-stanislas']"
    assert_no_match(/Térence|Ton parcours en 3 étapes/, response.body)
  end
end
