# frozen_string_literal: true

module Veille
  # Base commune aux deux passes IA.
  #
  # Le découpage est repris de l'AiEnricher de la branche ingestion-ia, qui
  # avait la bonne idée : deux méthodes de classe pures, testables sans
  # aucun appel réseau.
  #
  #   .prompt_for(...)   → hash de paramètres de requête (pur)
  #   .parse_response(t) → hash structuré (pur)
  #   #call / #qualify / #draft → orchestration synchrone
  class AiPass
    class ParseError < StandardError; end

    # Injectable pour les tests : n'importe quel objet répondant à #messages.
    def initialize(client: nil)
      @client = client
    end

    # Parsing robuste. Le modèle est prié de répondre en JSON strict et le
    # format structuré le contraint déjà, mais on garde le repêchage par
    # expression régulière au cas où il enroberait sa réponse de balises
    # Markdown.
    def self.parse_response(text)
      s = text.to_s.strip
      raise ParseError, "réponse vide du modèle" if s.empty?

      json_str = s[/\{[\s\S]*\}/] or
        raise ParseError, "aucun bloc JSON dans la réponse : #{s[0, 200]}"

      parsed = JSON.parse(json_str)
      raise ParseError, "le JSON racine n'est pas un objet" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      raise ParseError, "JSON invalide : #{e.message}"
    end

    private

    def client
      @client ||= AnthropicClient.new(
        model:        self.class::MODEL,
        timeout:      self.class::TIMEOUT,
        open_timeout: self.class::OPEN_TIMEOUT,
        retries:      self.class::RETRIES
      )
    end

    # Envoie la requête et rend le hash parsé.
    def run(params)
      response = client.messages(**params)
      self.class.parse_response(AnthropicClient.extract_text(response))
    end

    def self.json_schema_params(system:, user:, schema:, max_tokens:)
      {
        system:        system,
        messages:      [{ role: "user", content: user }],
        max_tokens:    max_tokens,
        output_config: { format: { type: "json_schema", schema: schema } }
      }
    end
  end
end
