require "test_helper"
require "minitest/mock"

# Balises de partage des fiches et images de repli.
class FichesPartageTest < ActionDispatch::IntegrationTest
  setup do
    Geocoder::Lookup::Test.set_default_stub([]) # adresses non géocodées : fiches sans carte
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
  end

  test "opportunité sans photo : Open Graph et Twitter Card, image de repli de la catégorie en URL absolue" do
    o = Opportunity.create!(title: "Repair Café", description: "**Réparer** " + ("ensemble " * 40), category: "ecologiser",
                            is_active: true, latitude: 48.69, longitude: 6.18)
    DioramaTuiles.stub(:new, @tuiles) { get opportunity_url(o) }

    assert_response :success
    assert_select "meta[property='og:title'][content='Repair Café']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    resume = css_select("meta[property='og:description']").first["content"]
    assert_operator resume.length, :<=, 150
    refute_includes resume, "**"
    image = css_select("meta[property='og:image']").first["content"]
    assert_match %r{\Ahttp://www\.example\.com/assets/fallback-opportunity-ecologiser-.*\.jpg\z}, image
    assert_select "[data-controller=diorama][data-diorama-mini-value=true]"
  end

  test "histoire : image de repli des Belles Histoires" do
    s = Story.create!(title: "Une histoire", chapo: "Chapô.", is_active: true, location: "Nancy")
    get story_url(s)

    assert_response :success
    assert_match %r{/assets/fallback-story-.*\.jpg\z}, css_select("meta[property='og:image']").first["content"]
  end

  test "les images de repli référencées existent" do
    %w[og_default.jpg fallback-opportunity.jpg fallback-story.jpg].each do |nom|
      assert Rails.root.join("app/assets/images", nom).exist?, nom
    end
    Opportunity::CATEGORIES.each do |cle|
      assert Rails.root.join("app/assets/images/fallback-opportunity-#{cle}.jpg").exist?, cle
    end
  end
end
