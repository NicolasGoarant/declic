require "test_helper"
require_relative "support"
require_relative "fake_anthropic_client"

class Veille::StoryDrafterTest < ActiveSupport::TestCase
  include VeilleSupport

  test "le brouillon porte la mention de la source et l'accord à obtenir" do
    c = candidat(origin: "presse", summary: "Une couturière rouvre l'atelier. Le quartier suit.", commune: "Laxou", item_type: "belle_histoire")
    client = FakeAnthropicClient.new(text: { brouillon: "Elle a rouvert la porte de l'atelier." }.to_json)

    Veille::StoryDrafter.new(client: client).draft(c)

    assert_includes c.draft_body, "Elle a rouvert la porte de l'atelier."
    assert_includes c.draft_body, "Source : Presse locale — #{c.url}"
    assert_includes c.draft_body, "Accord de la personne : à obtenir"
  end

  test "le prompt vise 120 mots, sans horaires ni appel à l'action" do
    params = Veille::StoryDrafter.prompt_for(title: "T", summary: "R", commune: "Laxou")
    assert_match "120 mots", params[:system]
    assert_match "ni horaires ni appel à l'action", params[:system]
  end

  test "ne rédige rien sans résumé" do
    assert_raises(ArgumentError) { Veille::StoryDrafter.new(client: FakeAnthropicClient.new(text: "{}")).draft(candidat) }
  end
end
