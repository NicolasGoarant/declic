# frozen_string_literal: true

module Veille
  # Base commune aux passes IA (AiEnricher, Redaction::Brouillon).
  #
  # Le découpage est repris de l'AiEnricher de la branche ingestion-ia, qui
  # avait la bonne idée : deux méthodes de classe pures, testables sans
  # aucun appel réseau.
  #
  #   .prompt_for(...)   → hash de paramètres de requête (pur)
  #   .parse_response(t) → hash structuré (pur)
  #   #enrich / #draft → orchestration synchrone
  class AiPass
    class ParseError < StandardError; end

    # Consommation du dernier appel : { "input_tokens" => n, "output_tokens" => n }.
    attr_reader :usage

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

    # Envoie la requête et rend le hash parsé. Chaque appel est journalisé
    # (Veille::AppelIa) avec sa consommation et son coût estimé, qu'il réussisse
    # ou non ; le plafond mensuel est vérifié avant tout envoi.
    def run(params, candidate: nil)
      verifier_plafond(candidate)
      debut = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        response = client.messages(**params)
      rescue AnthropicClient::Error => e
        journaliser(candidate, "erreur_api", debut, erreur: "#{e.class.name.demodulize} : #{e.message.slice(0, 300)}")
        raise
      end
      @usage = response["usage"]
      begin
        parsed = self.class.parse_response(AnthropicClient.extract_text(response))
      rescue ParseError => e
        journaliser(candidate, "illisible", debut, usage: @usage, erreur: e.message.slice(0, 300))
        raise
      end
      @appel = journaliser(candidate, "ok", debut, usage: @usage)
      parsed
    end

    # Dernier appel journalisé (pour que l'appelant requalifie son statut, par
    # exemple « refuse_controle » si les contrôles rejettent le brouillon).
    attr_reader :appel

    def verifier_plafond(candidate)
      Veille::Plafond.verifier!
    rescue Veille::Plafond::Depasse => e
      journaliser(candidate, "plafond", Process.clock_gettime(Process::CLOCK_MONOTONIC), erreur: e.message)
      raise
    end

    def journaliser(candidate, statut, debut, usage: nil, erreur: nil)
      Veille::AppelIa.create!(
        candidate: candidate, passe: self.class::PASSE, modele: self.class::MODEL, statut: statut,
        input_tokens: usage.to_h["input_tokens"].to_i, output_tokens: usage.to_h["output_tokens"].to_i,
        cout_usd: Veille::Cout.estimer(self.class::MODEL, usage), erreur: erreur,
        duree_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - debut) * 1000).round
      )
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
