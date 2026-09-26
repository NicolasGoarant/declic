require "test_helper"

class StoryThematiqueTest < ActiveSupport::TestCase
  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    base = { description: "Texte", is_active: true, latitude: 48.69, longitude: 6.18 }
    @formation = Opportunity.create!(base.merge(title: "Formation", category: "formation"))
    @ecologie = Opportunity.create!(base.merge(title: "Écologie", category: "ecologiser"))
  end

  def histoire(**attrs) = Story.create!({ title: "H #{SecureRandom.hex(3)}", location: "Nancy", is_active: true, latitude: 48.69, longitude: 6.18 }.merge(attrs))

  test "la thématique l'emporte sur les étiquettes" do
    s = histoire(thematique: "formation", tags: "ecologiser")
    assert_equal "formation", s.categorie_opportunite
    assert_equal [ @formation ], s.opportunites_proches(1)
  end

  test "sans thématique, les étiquettes puis la proximité" do
    assert_equal "ecologiser", histoire(tags: "Écologiser, jardin").categorie_opportunite
    assert_nil histoire(tags: "jardin").categorie_opportunite
    assert_equal 2, histoire.opportunites_proches.size
  end

  test "la thématique doit être une catégorie d'opportunité" do
    assert_not Story.new(title: "H", location: "Nancy", thematique: "cuisine").valid?
    assert Story.new(title: "H", location: "Nancy", thematique: "").valid?
  end
end
