require "test_helper"

class PointsFortsTest < ActiveSupport::TestCase
  test "une ligne de highlights_items = un point, texte seul" do
    points = PointsForts.depuis_lignes("- Une logistique de pointe\n\n• Une expertise 24h/24\r\nUn engagement citoyen\n")
    assert_equal [ "Une logistique de pointe", "Une expertise 24h/24", "Un engagement citoyen" ], points.map { |p| p["texte"] }
    assert(points.all? { |p| p["titre"] == "" && p["icone"] == "" })
    assert_empty PointsForts.depuis_lignes(nil)
  end

  test "normaliser garde les clés attendues et écarte les points vides" do
    brut = [ { titre: "Titre", texte: "Texte", autre: "x" }, { "icone" => "coeur" }, "pas un point" ]
    assert_equal [ { "icone" => "", "titre" => "Titre", "texte" => "Texte" } ], PointsForts.normaliser(brut)
  end

  test "une histoire accepte 3 points forts au plus" do
    histoire = Story.new(title: "Une histoire", location: "Nancy", latitude: 48.69, longitude: 6.18)
    histoire.points_forts = [ { "texte" => "a" } ] * 3
    assert histoire.valid?, histoire.errors.full_messages.to_sentence
    histoire.points_forts = [ { "texte" => "a" } ] * 4
    assert_not histoire.valid?
    assert histoire.errors.key?(:points_forts)
  end

  test "la migration reprend highlights_items dans points_forts, sans toucher aux highlights" do
    require Rails.root.join("db/migrate/20260926090300_reprend_highlights_des_histoires")
    avec = stories(:one)
    avec.update_columns(highlights_items: "Premier point\nDeuxième point\nTroisième\nQuatrième", points_forts: nil)
    sans = stories(:two)
    sans.update_columns(highlights_items: "", points_forts: nil)

    ActiveRecord::Migration.suppress_messages { ReprendHighlightsDesHistoires.new.up }

    assert_equal [ "Premier point", "Deuxième point", "Troisième" ], avec.reload.points_forts.map { |p| p["texte"] }
    assert_equal "Premier point\nDeuxième point\nTroisième\nQuatrième", avec.highlights_items
    assert_nil sans.reload.points_forts
  end
end
