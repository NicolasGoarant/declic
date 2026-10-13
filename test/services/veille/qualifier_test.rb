require "test_helper"
require_relative "fake_anthropic_client"

module Veille
  class QualifierTest < ActiveSupport::TestCase
    REPONSE = '{"category":"belle_histoire","score":87,"reason":"Personne nommée, initiative concrète, ancrage à Laxou."}'

    def candidat(**attrs)
      Veille::Candidate.create!({
        url:       "https://exemple.fr/a-#{SecureRandom.hex(4)}",
        title:     "Le jardin partagé de Laxou fête ses dix ans",
        excerpt:   "Trente familles cultivent 800 m² depuis 2016.",
        full_text: "TEXTE-INTEGRAL-CONFIDENTIEL " * 50
      }.merge(attrs))
    end

    test "utilise le modèle Haiku daté demandé" do
      assert_equal "claude-haiku-4-5-20251001", Veille::Qualifier::MODEL
    end

    test "qualifie et enregistre catégorie, score, motif et horodatage" do
      c = candidat
      fake = FakeAnthropicClient.new(text: REPONSE)

      resultat = Veille::Qualifier.new(client: fake).qualify(c)
      c.reload

      assert_equal "belle_histoire", c.category
      assert_equal 87, c.score
      assert_equal "Personne nommée, initiative concrète, ancrage à Laxou.", c.reason
      assert c.qualified?
      assert_equal "belle_histoire", resultat["category"]
    end

    test "la passe A n'envoie jamais le texte intégral au modèle" do
      c = candidat
      fake = FakeAnthropicClient.new(text: REPONSE)

      Veille::Qualifier.new(client: fake).qualify(c)

      assert_not_includes fake.user_content, "TEXTE-INTEGRAL-CONFIDENTIEL",
                          "le tri se fait sur titre + chapeau seulement"
      assert_includes fake.user_content, "Le jardin partagé de Laxou"
      assert_includes fake.user_content, "Trente familles cultivent"
    end

    test "demande du JSON strict via le format structuré" do
      fake = FakeAnthropicClient.new(text: REPONSE)
      Veille::Qualifier.new(client: fake).qualify(candidat)

      format = fake.last.dig(:output_config, :format)
      assert_equal "json_schema", format[:type]
      assert_equal %w[category score reason], format[:schema][:required]
      assert_equal %w[belle_histoire autre], format[:schema][:properties][:category][:enum]
    end

    test "le prompt système porte les trois critères et les exclusions" do
      prompt = Veille::Qualifier::SYSTEM_PROMPT

      assert_match(/personne nommée/i, prompt)
      assert_match(/collectif identifié/i, prompt)
      assert_match(/trajectoire ou une initiative concrète/i, prompt)
      assert_match(/Grand Nancy/, prompt)
      assert_match(/Meurthe-et-Moselle/, prompt)

      %w[fait divers résultats sportifs conseil municipal].each do |exclusion|
        assert_match(/#{Regexp.escape(exclusion.split.first)}/i, prompt)
      end
      assert_match(/annonces institutionnelles/i, prompt)
    end

    test "accepte une réponse enrobée de Markdown" do
      c = candidat
      fake = FakeAnthropicClient.new(text: "Voici :\n```json\n#{REPONSE}\n```")

      Veille::Qualifier.new(client: fake).qualify(c)
      assert_equal 87, c.reload.score
    end

    test "ramène un score hors bornes dans l'intervalle" do
      c = candidat
      fake = FakeAnthropicClient.new(text: '{"category":"autre","score":180,"reason":"x"}')

      Veille::Qualifier.new(client: fake).qualify(c)
      assert_equal 100, c.reload.score
    end

    test "une catégorie inconnue retombe sur autre" do
      c = candidat
      fake = FakeAnthropicClient.new(text: '{"category":"fait_divers","score":10,"reason":"x"}')

      Veille::Qualifier.new(client: fake).qualify(c)
      assert_equal "autre", c.reload.category
    end

    test "une réponse illisible lève ParseError et laisse le candidat repassable" do
      c = candidat
      fake = FakeAnthropicClient.new(text: "je ne sais pas répondre")

      assert_raises(Veille::AiPass::ParseError) { Veille::Qualifier.new(client: fake).qualify(c) }

      c.reload
      assert_not c.qualified?, "qualified_at reste nil : le candidat sera repassé"
      assert_nil c.score
    end

    test "une panne API remonte telle quelle sans qualifier" do
      c = candidat
      fake = FakeAnthropicClient.new(raise_with: AnthropicClient::ConnectionError.new("injoignable"))

      assert_raises(AnthropicClient::ConnectionError) { Veille::Qualifier.new(client: fake).qualify(c) }
      assert_not c.reload.qualified?
    end
  end
end
