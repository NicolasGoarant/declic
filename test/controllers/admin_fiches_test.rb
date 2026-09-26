require "test_helper"

class AdminFichesTest < ActionDispatch::IntegrationTest
  setup do
    @env = ENV.to_h.slice("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"] = "admin"
    ENV["ADMIN_PASSWORD"] = "secret"
    @headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret") }
    Opportunity.delete_all
    Story.delete_all
  end

  teardown do
    %w[ADMIN_USERNAME ADMIN_PASSWORD].each { |cle| ENV[cle] = @env[cle] }
  end

  def png = fixture_file_upload("pixel.png", "image/png")

  def opportunite(titre, **attributs)
    Opportunity.create!({ title: titre, description: "d", category: "benevolat" }.merge(attributs))
  end

  test "les formulaires s'affichent avec les nouveaux champs et sans highlights" do
    get new_admin_opportunity_url, headers: @headers
    assert_response :success
    %w[audience programme_texte organization_logo starts_on ends_on start_time end_time schedule_text
       cta_button_text cta_button_url city postal_code contact_phone published_at].each do |champ|
      assert_select "[name='opportunity[#{champ}]']", 1, "champ #{champ} absent"
    end
    assert_select "[name='opportunity[start_date]']", 0

    get new_admin_story_url, headers: @headers
    assert_response :success
    %w[venue_name discover_url quote_author source_published_on author_name author_email phone address city
       postal_code].each do |champ|
      assert_select "[name='story[#{champ}]']", 1, "champ #{champ} absent"
    end
    assert_select "[name^='story[points_forts_saisie]']", 9
    assert_select "[name*='highlights']", 0
    assert_select "[name*='cta_button']", 0
    assert_select "[name*='schedule']", 0
    assert_match "Une Belle Histoire raconte un parcours", response.body
  end

  test "créer une opportunité datée écrit starts_on et, par le pont, les chaînes" do
    post admin_opportunities_url, headers: @headers, params: { opportunity: {
      title: "Repair Café", category: "ecologiser", description: "Texte",
      starts_on: "2026-02-14", start_time: "14:00", end_time: "18:00",
      programme_texte: "Diagnostic\n\nAtelier\n", audience: "Tous"
    } }
    assert_redirected_to admin_opportunities_url
    o = Opportunity.find_by!(title: "Repair Café")
    assert_equal Date.new(2026, 2, 14), o.starts_on
    assert_equal "2026-02-14", o.start_date
    assert_equal "14h - 18h", o.horaire_affiche
    assert_equal %w[Diagnostic Atelier], o.programme
    assert_not o.permanente?
  end

  test "créer une opportunité permanente : pas de date, horaire en texte libre" do
    post admin_opportunities_url, headers: @headers, params: { opportunity: {
      title: "Don du sang", category: "benevolat", description: "Texte",
      schedule_text: "Ouvert toute l'année, sur rendez-vous"
    } }
    o = Opportunity.find_by!(title: "Don du sang")
    assert o.permanente?
    assert_nil o.start_date
    assert_equal "Ouvert toute l'année, sur rendez-vous", o.horaire_affiche
  end

  test "modifier une opportunité : effacer la date vide aussi la chaîne" do
    o = opportunite("À modifier", starts_on: Date.new(2026, 2, 14))
    assert_equal "2026-02-14", o.start_date
    patch admin_opportunity_url(o), headers: @headers, params: { opportunity: { starts_on: "" } }
    assert_nil o.reload.starts_on
    assert_nil o.start_date
  end

  test "créer une histoire avec trois photos ; les blocs de points forts vides sont ignorés" do
    post admin_stories_url, headers: @headers, params: {
      story: {
        title: "Un parcours", location: "Nancy", latitude: "48.69", longitude: "6.18", venue_name: "Chez Marie", quote: "Une citation",
        points_forts_saisie: {
          "0" => { icone: "coeur", titre: "Un", texte: "Texte un" },
          "1" => { icone: "goutte", titre: "", texte: "" },
          "2" => { icone: "", titre: "", texte: "" }
        }
      },
      galerie: { nouvelles: [ png, png, png ] }
    }
    assert_redirected_to admin_stories_url
    s = Story.find_by!(title: "Un parcours")
    assert_equal 1, s.points_forts.size
    assert_equal "Chez Marie", s.venue_name
    assert_equal 3, s.photos.count
  end

  test "galerie : positions et suppression individuelle via le formulaire" do
    s = Story.create!(title: "Galerie", location: "Nancy", latitude: 48.69, longitude: 6.18)
    s.appliquer_galerie(nouvelles: [ png, png, png ])
    a, b, c = s.photos_ordonnees.map(&:id)

    patch admin_story_url(s), headers: @headers, params: {
      story: { title: "Galerie" },
      galerie: { positions: { a => "3", b => "1", c => "2" }, supprimer: [ c ] }
    }
    assert_equal [ b, a ], s.reload.photos_ordonnees.map(&:id)
    assert_equal b, s.couverture.id
  end

  test "la recherche par titre marche sans ILIKE, sans tenir compte de la casse, jokers échappés" do
    opportunite("Repair Café Nancy")
    opportunite("Jardin partagé")
    opportunite("100% bénévole")

    get admin_opportunities_url, headers: @headers, params: { q: "repair" }
    assert_response :success
    assert_select ".row-title", text: "Repair Café Nancy"
    assert_select ".row-title", text: "Jardin partagé", count: 0

    get admin_opportunities_url, headers: @headers, params: { q: "%" }
    assert_select ".row-title", text: "100% bénévole"
    assert_select ".row-title", text: "Jardin partagé", count: 0
  end

  test "la colonne Fiche est triable par complétude" do
    opportunite("Pleine", image_url: "https://x/y.jpg", starts_on: Date.new(2026, 1, 1), address: "1 rue A",
                programme: [ "a" ], audience: "Tous", cta_button_text: "Go", cta_button_url: "https://x")
    opportunite("Vide")

    get admin_opportunities_url, headers: @headers, params: { tri: "fiche", sens: "asc" }
    assert_equal [ "Vide", "Pleine" ], css_select(".row-title").map(&:text)
    get admin_opportunities_url, headers: @headers, params: { tri: "fiche", sens: "desc" }
    assert_equal [ "Pleine", "Vide" ], css_select(".row-title").map(&:text)
    assert_select ".fiche-pct", text: "100 %"
  end

  test "la liste des histoires affiche la complétude" do
    Story.create!(title: "Une histoire", location: "Nancy", latitude: 48.69, longitude: 6.18)
    get admin_stories_url, headers: @headers, params: { tri: "fiche" }
    assert_response :success
    assert_select ".fiche-pct", text: "20 %"
  end

  test "la route geocode_missing des opportunités existe et répond" do
    assert_equal "/admin/opportunities/geocode_missing", geocode_missing_admin_opportunities_path
    post geocode_missing_admin_opportunities_url, headers: @headers
    assert_redirected_to admin_opportunities_url
  end

  test "sans identifiants configurés, les nouvelles routes restent en 403" do
    ENV.delete("ADMIN_PASSWORD")
    post geocode_missing_admin_opportunities_url, headers: @headers
    assert_response :forbidden
  end
end
