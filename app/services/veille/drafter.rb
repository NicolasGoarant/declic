# frozen_string_literal: true

module Veille
  # Passe B — rédaction du brouillon, sur le texte intégral.
  #
  # Tourne DANS la requête web (aucun worker dyno sur ce projet). Tous les
  # réglages ci-dessous découlent du budget de 30 s d'Heroku :
  #   open_timeout 5 s + timeout 22 s = 27 s au pire, sans retry.
  #
  # #draft ne persiste rien et ne crée aucune Story : il rend un hash que
  # l'admin relit et corrige dans un formulaire avant publication.
  class Drafter < AiPass
    MODEL        = "claude-sonnet-5"
    PASSE        = "redaction"
    TIMEOUT      = 22
    OPEN_TIMEOUT = 5
    # Zéro retry : sur le chemin web un second essai ferait sauter les 30 s.
    RETRIES      = 0
    MAX_TOKENS   = 2048

    # Plafond du texte envoyé au modèle. Garde le temps de réponse sous le
    # budget Heroku et borne le coût par appel. Un article de presse tient
    # très largement dedans ; au-delà, c'est en général que la page contient
    # aussi des commentaires ou des articles liés.
    MAX_FULL_TEXT_CHARS = 12_000

    SCHEMA = {
      type: "object",
      properties: {
        titre:            { type: "string" },
        personne:         { type: "string" },
        commune:          { type: "string" },
        resume:           { type: "string" },
        theme:            { type: "string" },
        champs_manquants: { type: "array", items: { type: "string" } }
      },
      required: %w[titre personne commune resume theme champs_manquants],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~TXT.freeze
      Tu prépares une fiche pour la rubrique « Belles Histoires » de Déclic, plateforme d'engagement citoyen du Grand Nancy. On te donne le texte d'un article repéré dans la presse locale ou dans une publication de collectivité. Tu en extrais les faits et tu rédiges un résumé.

      CONTRAINTE CENTRALE — REFORMULATION INTÉGRALE :
      Le résumé est une reformulation intégrale, dans un vocabulaire et une syntaxe qui te sont propres. Aucune phrase ni tournure de l'article d'origine n'y figure. Cela vaut aussi pour les formules courtes, les images et les jeux de mots du journaliste : ce sont précisément eux qu'il ne faut pas reprendre.

      Ce que tu conserves de l'article : les faits seuls — qui, quoi, où, quand. Les noms propres, les lieux, les dates et les chiffres se reprennent tels quels, ce sont des faits et non des formulations. Tout le reste s'écrit à neuf.

      Méthode : lis, retiens ce qui s'est passé, puis écris en regardant ailleurs. Si une de tes phrases pourrait être retrouvée à l'identique dans l'article, réécris-la.

      CE QUE TU NE FAIS JAMAIS :
      Tu ne combles aucun trou par déduction. Si l'article ne dit pas la commune, tu ne la devines pas depuis le nom du journal. S'il ne nomme personne clairement, tu n'attribues pas l'initiative à quelqu'un. Si tu hésites sur une date, tu ne l'arrondis pas. Chaque information absente ou incertaine se déclare dans champs_manquants — c'est à cela que ce champ sert, et le remplir n'est pas un échec. Une fiche honnêtement lacunaire vaut mieux qu'une fiche complète et fausse : un humain relit derrière toi et ira vérifier.

      Tu n'inventes aucune citation. Tu n'ajoutes ni morale, ni emphase, ni commentaire sur l'article.

      LES CHAMPS :

      titre : court, incarné, 80 caractères au plus. Il annonce le sujet sans le survendre. Pas de superlatif, pas de titre-appât.

      personne : la personne ou le petit collectif au centre de l'histoire, tel que l'article le nomme. Chaîne vide si l'article n'identifie personne — et alors « personne » va dans champs_manquants.

      commune : la commune d'ancrage. Chaîne vide si l'article ne la donne pas — et alors « commune » va dans champs_manquants. Ne la déduis jamais du titre du journal ni de la zone de diffusion.

      resume : exactement trois phrases. La première pose qui et quoi, la deuxième ce qui a été entrepris, la troisième où cela en est. Ton sobre et chaleureux, factuel, sans pathos. Pas d'emoji.

      theme : deux ou trois mots qui disent de quoi il retourne (par exemple « insertion par le travail », « jardin partagé », « réparation de vélos »). Pas une catégorie administrative.

      champs_manquants : la liste des informations que l'article ne fournit pas et qu'un relecteur devra chercher. Tableau vide si rien ne manque, ce qui est rare.

      Réponds UNIQUEMENT par l'objet JSON demandé. Aucun commentaire, aucune balise de code, aucune prose autour.
    TXT

    # Pur : construit les paramètres de requête. Testable sans réseau.
    def self.prompt_for(full_text:, title: nil, url: nil, published_on: nil)
      lines = []
      lines << "Titre repéré : #{title}"        if title.present?
      lines << "URL source : #{url}"            if url.present?
      lines << "Date de publication : #{published_on}" if published_on.present?
      lines << ""
      lines << "Texte de l'article :"
      lines << full_text.to_s

      json_schema_params(
        system:     SYSTEM_PROMPT,
        user:       lines.join("\n"),
        schema:     SCHEMA,
        max_tokens: MAX_TOKENS
      )
    end

    # Tronque le texte au plafond, en journalisant quand cela arrive.
    def self.truncate(full_text, candidate_id: nil)
      text = full_text.to_s
      return text if text.length <= MAX_FULL_TEXT_CHARS

      Rails.logger.info(
        "[Veille::Drafter] full_text tronqué pour le candidat " \
        "##{candidate_id || '?'} : #{text.length} → #{MAX_FULL_TEXT_CHARS} caractères"
      )
      text[0, MAX_FULL_TEXT_CHARS]
    end

    # Rend un hash : titre, personne, commune, resume, theme, champs_manquants.
    # Ne persiste rien — le brouillon repart vers un formulaire éditable.
    #
    # Lève ArgumentError si full_text est vide (le tampon a déjà été purgé,
    # ou l'admin n'a rien collé), AnthropicClient::Error sur incident API,
    # Veille::AiPass::ParseError sur réponse illisible.
    def draft(candidate)
      text = self.class.truncate(candidate.full_text, candidate_id: candidate.id)
      raise ArgumentError, "full_text vide : rien à rédiger" if text.blank?

      result = run(self.class.prompt_for(
        full_text:    text,
        title:        candidate.title,
        url:          candidate.url,
        published_on: candidate.published_on
      ), candidate: candidate)

      normalize(result)
    end

    private

    def normalize(result)
      {
        "titre"            => result["titre"].to_s.strip,
        "personne"         => result["personne"].to_s.strip,
        "commune"          => result["commune"].to_s.strip,
        "resume"           => result["resume"].to_s.strip,
        "theme"            => result["theme"].to_s.strip,
        "champs_manquants" => Array(result["champs_manquants"]).map { |v| v.to_s.strip }.reject(&:blank?)
      }
    end
  end
end
