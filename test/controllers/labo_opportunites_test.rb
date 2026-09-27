require "test_helper"
require "minitest/mock"

# Les cartes de la grille sont clonées côté client (explorateur_controller.js) depuis un <template> :
# on ne peut donc pas compter de « .lb-carte » dans la réponse (le <template> lui-même en contient un,
# toujours). Les assertions portent sur les points JSON (data-*-points-value) qui alimentent la carte
# et la grille, et sur ce qui est bien rendu côté serveur (catégories, en-tête, barre du labo).
class LaboOpportunitesTest < ActionDispatch::IntegrationTest
  setup do
    Opportunity.delete_all
    Story.delete_all
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { true })
  end

  def visiter
    DioramaTuiles.stub(:new, @tuiles) { get labo_opportunites_url }
  end

  def opportunite(titre, **attributs)
    Opportunity.create!({ title: titre, description: "Un texte de présentation.", category: "benevolat",
                           latitude: 48.69, longitude: 6.18, is_active: true }.merge(attributs))
  end

  def points_json
    doc = Nokogiri::HTML(response.body)
    JSON.parse(doc.at_css("[data-explorateur-points-value]")["data-explorateur-points-value"])
  end

  test "répond, hors index, avec la barre du labo et les 5 catégories réelles (pas 8, pas les libellés de la maquette)" do
    visiter
    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "header.acc-barre"
    assert_select ".lb-cat--toutes"
    assert_select ".lb-cat[data-cle]", Opportunity::CATEGORIES.size
    assert_select ".lb-cat[data-cle]" do |boutons|
      assert_equal Opportunity::CATEGORIES.sort, boutons.map { |b| b["data-cle"] }.sort
    end
    assert_select ".lb-cat", text: /Culture & Loisirs|Solidarité/, count: 0
  end

  test "une opportunité active et géolocalisée apparaît dans les points (carte et grille)" do
    opportunite("Repair Café", category: "ecologiser")
    visiter

    titres = points_json.map { |p| p["titre"] }
    assert_equal [ "Repair Café" ], titres
    assert_equal "ecologiser", points_json.first["categorie"]
    assert_kind_of Float, points_json.first["latitude"]
  end

  test "une opportunité inactive n'apparaît pas" do
    opportunite("Cachée", is_active: false)
    visiter
    assert_equal [], points_json
  end

  test "une opportunité sans coordonnées n'apparaît pas (pas de pin possible)" do
    opportunite("Sans lieu", latitude: nil, longitude: nil)
    visiter
    assert_equal [], points_json
  end

  test "règle éditoriale : aucune Belle Histoire sur cette page" do
    opportunite("Une opportunité")
    Story.create!(title: "Une histoire", is_active: true, latitude: 48.69, longitude: 6.18,
                  thematique: "benevolat", location: "Nancy")
    visiter
    assert_equal [ "Une opportunité" ], points_json.map { |p| p["titre"] }
  end
end
