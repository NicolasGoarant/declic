require "test_helper"

class StoryOpportunitesProchesTest < ActiveSupport::TestCase
  setup do
    Opportunity.delete_all
    Geocoder::Lookup::Test.set_default_stub([])
    base = { description: "Texte", is_active: true }
    @proche = Opportunity.create!(base.merge(title: "Proche", category: "formation", latitude: 48.70, longitude: 6.19))
    @loin = Opportunity.create!(base.merge(title: "Loin", category: "entreprendre", latitude: 49.10, longitude: 6.20))
  end

  def histoire(**attrs) = Story.create!({ title: "H #{SecureRandom.hex(3)}", location: "Nancy", is_active: true, latitude: 48.69, longitude: 6.18 }.merge(attrs))

  test "les opportunités sont classées par proximité seule" do
    assert_equal [ @proche, @loin ], histoire.opportunites_proches
  end

  test "une étiquette de catégorie ne change plus le choix" do
    assert_equal [ @proche ], histoire(tags: "entreprendre").opportunites_proches(1)
  end

  test "sans coordonnées, l'histoire propose quand même des opportunités" do
    assert_equal 2, histoire(latitude: nil, longitude: nil).opportunites_proches.size
  end
end
