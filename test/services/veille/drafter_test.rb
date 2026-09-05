require "test_helper"
require "minitest/mock"
require_relative "fake_anthropic_client"

module Veille
  class DrafterTest < ActiveSupport::TestCase
    REPONSE = <<~JSON
      {"titre":"Le jardin qui a remplacé le parking",
       "personne":"Sylvie Mangin",
       "commune":"Laxou",
       "resume":"Sylvie Mangin cultive un terrain municipal depuis 2016. Elle y a monté un jardin partagé avec trente familles. Le collectif prépare aujourd'hui son extension.",
       "theme":"jardin partagé",
       "champs_manquants":["date exacte d'ouverture"]}
    JSON

    def candidat(**attrs)
      Veille::Candidate.create!({
        url:       "https://exemple.fr/a-#{SecureRandom.hex(4)}",
        title:     "Un jardin à Laxou",
        full_text: "Le texte intégral de l'article.",
        status:    "retenu"
      }.merge(attrs))
    end

    test "utilise Sonnet 5" do
      assert_equal "claude-sonnet-5", Veille::Drafter::MODEL
    end

    test "rend les six champs demandés" do
      d = Veille::Drafter.new(client: FakeAnthropicClient.new(text: REPONSE)).draft(candidat)

      assert_equal %w[titre personne commune resume theme champs_manquants].sort, d.keys.sort
      assert_equal "Sylvie Mangin", d["personne"]
      assert_equal "Laxou", d["commune"]
      assert_equal ["date exacte d'ouverture"], d["champs_manquants"]
    end

    test "ne persiste rien : le brouillon repart vers un formulaire" do
      c = candidat
      Veille::Drafter.new(client: FakeAnthropicClient.new(text: REPONSE)).draft(c)

      c.reload
      assert_equal "Un jardin à Laxou", c.title, "le titre du candidat n'est pas écrasé"
      assert c.full_text?, "le tampon n'est purgé qu'à la création de la fiche"
      assert_nil Story.find_by(veille_candidate_id: c.id), "aucune fiche n'est créée ici"
    end

    # ------------------------------------------------------------------
    # Plafond de 12 000 caractères.
    # ------------------------------------------------------------------
    test "tronque le texte au plafond et journalise la troncature" do
      c = candidat(full_text: "a" * 30_000)
      fake = FakeAnthropicClient.new(text: REPONSE)

      messages = []
      Rails.logger.stub(:info, ->(m) { messages << m }) do
        Veille::Drafter.new(client: fake).draft(c)
      end

      envoye = fake.user_content
      assert_includes envoye, "a" * Veille::Drafter::MAX_FULL_TEXT_CHARS
      assert_not_includes envoye, "a" * (Veille::Drafter::MAX_FULL_TEXT_CHARS + 1),
                          "le texte doit être coupé net au plafond"
      assert messages.any? { |m| m.to_s.include?("tronqué") && m.to_s.include?("30000") },
             "la troncature doit laisser une trace : #{messages.inspect}"
    end

    test "un texte sous le plafond passe intact et sans log de troncature" do
      c = candidat(full_text: "b" * 500)
      fake = FakeAnthropicClient.new(text: REPONSE)

      messages = []
      Rails.logger.stub(:info, ->(m) { messages << m }) do
        Veille::Drafter.new(client: fake).draft(c)
      end

      assert_includes fake.user_content, "b" * 500
      assert_not_includes fake.user_content, "b" * 501
      assert_empty messages.select { |m| m.to_s.include?("tronqué") }
    end

    test "le plafond vaut bien 12 000" do
      assert_equal 12_000, Veille::Drafter::MAX_FULL_TEXT_CHARS
    end

    # ------------------------------------------------------------------
    # Budget Heroku.
    # ------------------------------------------------------------------
    test "reste sous les 30 s d'Heroku, sans retry" do
      assert_equal 0, Veille::Drafter::RETRIES, "un retry doublerait le temps de réponse"
      assert_operator Veille::Drafter::TIMEOUT + Veille::Drafter::OPEN_TIMEOUT, :<, 30
    end

    # ------------------------------------------------------------------
    # Le prompt système.
    # ------------------------------------------------------------------
    test "le prompt impose la reformulation intégrale et interdit la déduction" do
      prompt = Veille::Drafter::SYSTEM_PROMPT

      assert_match(/reformulation intégrale/i, prompt)
      assert_match(/vocabulaire et .*syntaxe/i, prompt)
      assert_match(/Aucune phrase ni tournure de l'article d'origine/i, prompt)
      assert_match(/champs_manquants/, prompt)
      assert_match(/ne combles aucun trou par déduction/i, prompt)
      assert_match(/trois phrases/i, prompt)
    end

    test "demande du JSON strict via le format structuré" do
      fake = FakeAnthropicClient.new(text: REPONSE)
      Veille::Drafter.new(client: fake).draft(candidat)

      format = fake.last.dig(:output_config, :format)
      assert_equal "json_schema", format[:type]
      assert_equal %w[titre personne commune resume theme champs_manquants],
                   format[:schema][:required]
    end

    # ------------------------------------------------------------------
    # Cas limites.
    # ------------------------------------------------------------------
    test "un tampon vide lève ArgumentError sans appeler l'API" do
      c = candidat(full_text: nil)
      fake = FakeAnthropicClient.new(text: REPONSE)

      assert_raises(ArgumentError) { Veille::Drafter.new(client: fake).draft(c) }
      assert_empty fake.calls, "on n'appelle pas Sonnet pour rien"
    end

    test "normalise les champs absents plutôt que de renvoyer nil" do
      fake = FakeAnthropicClient.new(text: '{"titre":"T","resume":"R"}')
      d = Veille::Drafter.new(client: fake).draft(candidat)

      assert_equal "", d["personne"]
      assert_equal "", d["commune"]
      assert_equal [], d["champs_manquants"]
    end

    test "une réponse illisible lève ParseError" do
      fake = FakeAnthropicClient.new(text: "désolé")
      assert_raises(Veille::AiPass::ParseError) { Veille::Drafter.new(client: fake).draft(candidat) }
    end
  end
end
