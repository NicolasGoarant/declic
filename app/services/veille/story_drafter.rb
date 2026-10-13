# frozen_string_literal: true

module Veille
  # Brouillon d'environ 120 mots pour une belle histoire repérée, à partir du
  # titre et du résumé reformulé (jamais de l'article intégral). Le brouillon se
  # termine toujours par la mention de la source et le champ
  # « Accord de la personne : à obtenir » : rien ne se publie sans cet accord.
  class StoryDrafter < AiPass
    MODEL        = "claude-sonnet-5"
    TIMEOUT      = 40
    OPEN_TIMEOUT = 5
    RETRIES      = 1
    MAX_TOKENS   = 600
    MOTS_VISES   = 120

    SCHEMA = {
      type: "object",
      properties: { brouillon: { type: "string" } },
      required: %w[brouillon],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~TXT.freeze
      Tu rédiges, pour la rubrique « Belles Histoires » de Déclic (plateforme d'engagement citoyen du Grand Nancy), un brouillon d'environ #{MOTS_VISES} mots à partir d'un titre et d'un résumé. C'est un récit inspirant sur une personne ou un collectif : il raconte, il ne donne ni horaires ni appel à l'action directe.

      Écris à neuf, avec tes propres mots ; aucune phrase du résumé ne se retrouve telle quelle. Ton sobre et chaleureux. N'invente rien : pas de citation, pas de chiffre, pas de détail absents du résumé. Ce qui manque, tu le laisses de côté plutôt que de le deviner.

      Réponds UNIQUEMENT par l'objet JSON demandé : le brouillon est un seul paragraphe de prose, sans titre ni mention de source (ils sont ajoutés ensuite).
    TXT

    def self.prompt_for(title:, summary:, commune: nil)
      lignes = ["Titre : #{title}", "Résumé : #{summary}"]
      lignes << "Commune : #{commune}" if commune.present?
      json_schema_params(system: SYSTEM_PROMPT, user: lignes.join("\n"), schema: SCHEMA, max_tokens: MAX_TOKENS)
    end

    # Mentions obligatoires, ajoutées par le code et non par le modèle : elles ne
    # peuvent pas être oubliées.
    def self.finaliser(brouillon, source_label:, url:)
      <<~TXT.strip
        #{brouillon.to_s.strip}

        Source : #{source_label} — #{url}
        Accord de la personne : à obtenir
      TXT
    end

    def draft(candidate)
      raise ArgumentError, "résumé manquant : rien à rédiger" if candidate.summary.blank?

      result = run(self.class.prompt_for(title: candidate.title, summary: candidate.summary, commune: candidate.commune))
      candidate.update!(draft_body: self.class.finaliser(result["brouillon"], source_label: candidate.source_label, url: candidate.url))
      candidate
    end
  end
end
