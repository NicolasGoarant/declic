# frozen_string_literal: true

module Veille
  # Passe A — tri grossier, sur title + excerpt uniquement.
  #
  # Volontairement bon marché : Haiku, quelques centaines de tokens par
  # candidat. Elle ne lit JAMAIS le texte intégral de l'article ; son rôle
  # est seulement de dire si le sujet mérite qu'on aille plus loin.
  class Qualifier < AiPass
    MODEL        = "claude-haiku-4-5-20251001"
    TIMEOUT      = 20
    OPEN_TIMEOUT = 5
    # La qualification tourne en tâche rake, jamais dans la requête web :
    # un retry y est sans danger.
    RETRIES      = 1
    MAX_TOKENS   = 512

    SCHEMA = {
      type: "object",
      properties: {
        category: { type: "string", enum: Veille::Candidate::CATEGORIES },
        score:    { type: "integer", minimum: 0, maximum: 100 },
        reason:   { type: "string" }
      },
      required: %w[category score reason],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~TXT.freeze
      Tu es assistant de veille éditoriale pour Déclic, plateforme d'engagement citoyen du Grand Nancy. On te donne le titre et le chapeau d'un article de presse locale ou d'une publication de collectivité. Tu dis s'il pourrait nourrir la rubrique « Belles Histoires », et avec quelle force.

      CE QU'EST UNE BELLE HISTOIRE — trois éléments, à réunir :

      1. Elle met en scène une personne nommée, ou un petit collectif identifié (une association, une équipe, une famille, un commerce). Il y a quelqu'un derrière les faits, pas seulement une structure ou un dispositif.

      2. Elle raconte une trajectoire ou une initiative concrète : quelque chose a été entrepris, tenté, transformé, tenu dans la durée. Il se passe quelque chose que l'on peut raconter.

      3. Elle s'ancre dans le Grand Nancy ou en Meurthe-et-Moselle. Le lieu est identifiable.

      LE SCORE, de 0 à 100, reflète la force de ces trois éléments RÉUNIS. Les trois présents et nets : au-dessus de 75. Deux nets et le troisième seulement esquissé : entre 40 et 75. Un seul, ou trois vagues : en dessous de 40. Un sujet fort mais situé hors du territoire ne monte pas : l'ancrage local est une condition, pas un bonus.

      CATÉGORIE « autre » — sans hésiter, quel que soit l'intérêt du sujet :
      - les faits divers (accidents, délits, procès, incendies, disparitions) ;
      - les résultats sportifs et les comptes rendus de match ;
      - les comptes rendus de conseil municipal, communautaire, départemental ;
      - les annonces institutionnelles : inaugurations, budgets votés, nominations, communiqués, calendriers de travaux, campagnes de communication.
      Ces sujets reçoivent « autre » même quand une personne y est nommée et même quand ils se déroulent à Nancy.

      Dans le doute entre les deux catégories, choisis « autre » et explique pourquoi dans reason : la file de tri est relue à la main, un faux négatif coûte moins cher qu'un faux positif.

      RÉDACTION DE reason : une seule phrase, en français, qui dit ce qui fait pencher la balance. Sois concret — nomme l'élément qui manque ou celui qui emporte la décision. Pas de formule creuse du type « article intéressant ».

      Tu n'as que le titre et le chapeau. N'invente rien, ne suppose pas ce que l'article pourrait contenir de plus : juge sur ce que tu as.

      Réponds UNIQUEMENT par l'objet JSON demandé. Aucun commentaire, aucune balise de code, aucune prose autour.
    TXT

    # Pur : construit les paramètres de requête. Testable sans réseau.
    def self.prompt_for(title:, excerpt:, source_name: nil, published_on: nil)
      lines = []
      lines << "Titre : #{title.to_s.strip}"
      lines << "Chapeau : #{excerpt.to_s.strip.presence || '(aucun)'}"
      lines << "Source : #{source_name}"       if source_name.present?
      lines << "Date de publication : #{published_on}" if published_on.present?

      json_schema_params(
        system:     SYSTEM_PROMPT,
        user:       "Article à qualifier :\n\n#{lines.join("\n")}",
        schema:     SCHEMA,
        max_tokens: MAX_TOKENS
      )
    end

    # Qualifie le candidat ET enregistre le résultat (category, score,
    # reason, qualified_at). Retourne le hash renvoyé par le modèle.
    #
    # Lève AnthropicClient::Error ou Veille::AiPass::ParseError : l'appelant
    # décide quoi en faire. Le candidat reste alors non qualifié
    # (qualified_at nil) et sera repassable.
    def qualify(candidate)
      result = run(self.class.prompt_for(
        title:        candidate.title,
        excerpt:      candidate.excerpt,
        source_name:  candidate.source_label,
        published_on: candidate.published_on
      ))

      candidate.update!(
        category:     normalize_category(result["category"]),
        score:        normalize_score(result["score"]),
        reason:       result["reason"].to_s.strip.presence,
        qualified_at: Time.current
      )

      result
    end

    private

    def normalize_category(value)
      v = value.to_s.strip
      Veille::Candidate::CATEGORIES.include?(v) ? v : "autre"
    end

    def normalize_score(value)
      Integer(value).clamp(0, 100)
    rescue ArgumentError, TypeError
      0
    end
  end
end
