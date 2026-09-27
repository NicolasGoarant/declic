require "test_helper"
require "minitest/mock"

class LaboBellesHistoiresTest < ActionDispatch::IntegrationTest
  setup do
    Opportunity.delete_all
    Story.delete_all
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { true })
  end

  def visiter
    DioramaTuiles.stub(:new, @tuiles) { get labo_belles_histoires_url }
  end

  def histoire(titre, **attributs)
    Story.create!({ title: titre, location: "Nancy", latitude: 48.69, longitude: 6.18,
                    thematique: "benevolat", is_active: true }.merge(attributs))
  end

  def points_json
    doc = Nokogiri::HTML(response.body)
    JSON.parse(doc.at_css("[data-explorateur-points-value]")["data-explorateur-points-value"])
  end

  test "répond, hors index, filtrée par les 5 thématiques réelles (pas celles de la maquette)" do
    visiter
    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select ".lb-cat[data-cle]", Opportunity::CATEGORIES.size
    assert_select ".lb-cat[data-cle]" do |boutons|
      assert_equal Opportunity::CATEGORIES.sort, boutons.map { |b| b["data-cle"] }.sort
    end
    assert_select ".lb-cat", text: /Reconversion|Solidarité/, count: 0
  end

  test "une belle histoire active porte sa citation, sa thématique et le mois/année de publication, sans horaire" do
    histoire("Le déclic de Camille", thematique: "ecologiser", quote: "J'ai osé.",
             source_published_on: Date.new(2026, 2, 1))
    visiter

    point = points_json.first
    assert_equal "Le déclic de Camille", point["titre"]
    assert_equal "ecologiser", point["categorie"]
    assert_equal "histoires", point["icone_categorie"]
    assert_equal "J'ai osé.", point["citation"]
    assert_equal "Février 2026", point["date_affichee"]
    assert_not point.key?("horaire")
  end

  test "une belle histoire inactive n'apparaît pas" do
    histoire("Cachée", is_active: false)
    visiter
    assert_equal [], points_json
  end

  test "règle éditoriale : aucune Opportunité sur cette page" do
    histoire("Une histoire")
    Opportunity.create!(title: "Une opportunité", description: "d", category: "benevolat",
                         latitude: 48.69, longitude: 6.18, is_active: true)
    visiter
    assert_equal [ "Une histoire" ], points_json.map { |p| p["titre"] }
  end
end
