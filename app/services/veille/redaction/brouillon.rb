# frozen_string_literal: true

module Veille
  module Redaction
    # Rédige le récit d'une belle histoire (environ 120 mots) pour un candidat.
    # Remplace StoryDrafter (automatique, depuis le résumé) et Drafter (manuel,
    # depuis le texte collé) : un seul prompt, une seule règle éditoriale, un seul
    # enregistrement du résultat.
    #
    #   Brouillon.new.draft(candidat)                 # veille automatique : résumé + chapeau
    #   Brouillon.new(profil: :web).draft(c, texte: t) # relecteur : texte collé de l'article
    #
    # Le brouillon est enregistré dans draft_body, avec ses manques, le résultat des
    # contrôles et un statut (draft_status). Il ne crée aucune fiche : seule
    # Veille::Validation en crée une, après relecture.
    class Brouillon < AiPass
      MODEL        = "claude-sonnet-5"
      PASSE        = "redaction"
      OPEN_TIMEOUT = 5
      MAX_TOKENS   = 900
      MOTS_VISES   = 120
      # Plafond du texte collé : borne le temps de réponse et le coût.
      MAX_TEXTE    = 12_000

      # Le relecteur attend dans une requête web (budget Heroku : 30 s, aucun
      # worker) : 5 + 22 s, sans nouvel essai. La tâche rake peut patienter et
      # réessayer.
      PROFILS = {
        web: { timeout: 22, retries: 0 },
        lot: { timeout: 40, retries: 1 }
      }.freeze
      TIMEOUT = PROFILS[:lot][:timeout]
      RETRIES = PROFILS[:lot][:retries]

      SCHEMA = {
        type: "object",
        properties: {
          brouillon:        { type: "string" },
          personne:         { type: "string" },
          champs_manquants: { type: "array", items: { type: "string" } }
        },
        required: %w[brouillon personne champs_manquants],
        additionalProperties: false
      }.freeze

      SYSTEM_PROMPT = <<~TXT.freeze
        Tu rédiges, pour la rubrique « Belles Histoires » de Déclic (plateforme d'engagement citoyen du Grand Nancy), le brouillon d'un récit d'environ #{MOTS_VISES} mots à partir d'un élément repéré (résumé et chapeau, ou texte d'article). Un humain relit derrière toi.

        RÈGLE ÉDITORIALE : c'est un récit inspirant sur une personne ou un collectif. Il raconte ; il ne donne ni horaires ni appel à l'action directe (pas de « venez », « inscrivez-vous », « rejoignez »), ni adresse web, e-mail ou numéro de téléphone.

        REFORMULATION INTÉGRALE : écris à neuf, avec tes propres mots. Aucune phrase ni tournure de la source ne se retrouve telle quelle, pas même une formule courte ou une image du journaliste. Tu ne gardes que les faits : qui, quoi, où, quand. Les noms propres, lieux, dates et chiffres se reprennent tels quels.

        RIEN QUI NE SOIT DANS LA SOURCE : n'invente aucun détail, aucune circonstance, aucun motif, aucune cause, aucune conséquence ni aucune tournure factuelle qui ne figure pas dans la source. Pas de généralités de remplissage (« illustre les mutations du tissu local », « ouvre un nouveau chapitre », « un phénomène suivi de près »), pas d'interprétation, pas de contexte puisé dans tes connaissances. Rédige uniquement à partir de ce qui est donné, quitte à un texte nettement plus court et plus sobre que #{MOTS_VISES} mots : un texte court et exact vaut mieux qu'un texte long et brodé.

        CE QUE TU NE FAIS JAMAIS : combler un trou par déduction. Pas de citation inventée, pas de chiffre, de nom ou de détail absents de la source. Si la commune n'est pas dite, tu ne la devines pas ; si personne n'est clairement nommé, tu n'attribues l'initiative à personne. Chaque information absente ou incertaine se déclare dans champs_manquants : le remplir n'est pas un échec, une fiche honnêtement lacunaire vaut mieux qu'une fiche complète et fausse. Ni morale, ni emphase, ni commentaire sur la source.

        Ton sobre et chaleureux, factuel, sans pathos ni emoji.

        CHAMPS :
        - brouillon : un seul paragraphe de prose, sans titre ni mention de source (ils sont ajoutés ensuite).
        - personne : la personne ou le petit collectif au centre de l'histoire, tel que la source le nomme. Chaîne vide si personne n'est identifié.
        - champs_manquants : ce que la source ne donne pas et qu'un relecteur devra chercher (par exemple « personne », « commune »). Tableau vide si rien ne manque.

        Réponds UNIQUEMENT par l'objet JSON demandé.
      TXT

      Resultat = Struct.new(:brouillon, :personne, :manques, :controles, keyword_init: true)

      # Mentions obligatoires, ajoutées par le code et non par le modèle : elles ne
      # peuvent pas être oubliées.
      def self.finaliser(brouillon, source_label:, url:, accord_obtenu_at: nil)
        accord = accord_obtenu_at ? "obtenu le #{accord_obtenu_at.to_date.strftime("%d/%m/%Y")}" : "à obtenir"
        <<~TXT.strip
          #{brouillon.to_s.strip}

          Source : #{source_label} — #{url}
          Accord de la personne : #{accord}
        TXT
      end

      MENTIONS = /\n*Source : .*\nAccord de la personne : .*\z/

      # Le récit seul, sans les mentions que le code ajoute (c'est ce que le relecteur édite).
      def self.sans_mentions(corps) = corps.to_s.sub(MENTIONS, "").strip

      # Recompose le corps enregistré : récit (éventuellement corrigé à la main) + mentions à jour.
      def self.recomposer(candidate, recit)
        finaliser(recit, source_label: candidate.source_label, url: candidate.url, accord_obtenu_at: candidate.accord_obtenu_at)
      end

      # Ce que le modèle reçoit ; c'est aussi la référence des contrôles (citations,
      # chiffres, copie). Pur.
      def self.source_pour(candidate, texte: nil)
        if texte.present?
          [candidate.title, texte.to_s.slice(0, MAX_TEXTE)].compact_blank.join("\n\n")
        else
          [candidate.title, candidate.summary, candidate.excerpt].compact_blank.join("\n\n")
        end
      end

      def self.prompt_for(candidate, texte: nil)
        lignes = ["Titre repéré : #{candidate.title}"]
        lignes << "Commune : #{candidate.commune}" if candidate.commune.present?
        lignes << "Source : #{candidate.source_label}" if candidate.url.present?
        lignes << "Date de publication : #{candidate.published_on}" if candidate.published_on
        lignes << ""
        if texte.present?
          lignes << "Texte de l'article :"
          lignes << texte.to_s.slice(0, MAX_TEXTE)
        else
          lignes << "Résumé : #{candidate.summary}"
          lignes << "Chapeau : #{candidate.excerpt}" if candidate.excerpt.present?
        end
        json_schema_params(system: SYSTEM_PROMPT, user: lignes.join("\n"), schema: SCHEMA, max_tokens: MAX_TOKENS)
      end

      def initialize(client: nil, profil: :lot)
        super(client: client)
        @profil = PROFILS.fetch(profil)
      end

      # Rédige, contrôle et enregistre. Lève ArgumentError s'il n'y a rien à
      # raconter, Veille::Plafond::Depasse si le budget du mois est atteint (rien
      # n'est envoyé), AnthropicClient::Error ou AiPass::ParseError sur incident :
      # le candidat passe alors en « à reprendre » et l'essai est compté.
      def draft(candidate, texte: nil)
        source = self.class.source_pour(candidate, texte: texte)
        raise ArgumentError, "rien à rédiger : ni résumé ni texte" if texte.blank? && candidate.summary.blank?

        if texte.to_s.length > MAX_TEXTE
          Rails.logger.info("[Veille::Redaction] texte tronqué pour le candidat ##{candidate.id} : #{texte.length} → #{MAX_TEXTE} caractères")
        end

        resultat = demander(candidate, texte, source)
        enregistrer(candidate, resultat)
        resultat
      end

      private

      def demander(candidate, texte, source)
        brut = run(self.class.prompt_for(candidate, texte: texte), candidate: candidate)
        normaliser(brut, source)
      rescue Veille::Plafond::Depasse
        raise
      rescue AnthropicClient::Error, ParseError
        candidate.update!(draft_status: "a_reprendre", draft_attempts: candidate.draft_attempts + 1)
        raise
      end

      def normaliser(brut, source)
        corps   = brut["brouillon"].to_s.strip
        personne = brut["personne"].to_s.strip
        manques = Array(brut["champs_manquants"]).map { |m| m.to_s.strip }.reject(&:blank?)
        manques << "personne" if personne.blank? && manques.none? { |m| m.match?(/personne/i) }
        Resultat.new(brouillon: corps, personne: personne, manques: manques,
                     controles: Controles.verifier(corps, source: source, manques: manques))
      end

      def enregistrer(candidate, resultat)
        bloque = resultat.controles.bloque?
        # Un brouillon refusé par les contrôles reste lisible pour être corrigé à la main.
        appel&.update!(statut: "refuse_controle") if bloque
        candidate.update!(
          draft_body: self.class.finaliser(resultat.brouillon, source_label: candidate.source_label, url: candidate.url,
                                                              accord_obtenu_at: candidate.accord_obtenu_at),
          draft_manques: resultat.manques, draft_controles: resultat.controles.as_json,
          draft_status: bloque ? "a_verifier" : "redige", draft_attempts: candidate.draft_attempts + 1
        )
      end

      def client
        @client ||= AnthropicClient.new(model: MODEL, timeout: @profil[:timeout], open_timeout: OPEN_TIMEOUT,
                                        retries: @profil[:retries])
      end
    end
  end
end
