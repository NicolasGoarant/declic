# frozen_string_literal: true

module Veille
  # Propose, pour un élément brut : son type (opportunité ou belle histoire, selon
  # la règle éditoriale), sa catégorie Déclic, sa commune du Grand Nancy, sa date
  # ou son régime, et un résumé reformulé en deux phrases. Écarte (sans publier
  # quoi que ce soit) ce qui est hors Grand Nancy ou passé.
  #
  # Haiku suffit : tâche de classification sur un texte court, en lot.
  class AiEnricher < AiPass
    MODEL        = "claude-haiku-4-5-20251001"
    PASSE        = "enrichissement"
    TIMEOUT      = 30
    OPEN_TIMEOUT = 5
    RETRIES      = 1
    MAX_TOKENS   = 700
    # Plafond de texte envoyé : borne le coût, et une fiche d'agenda ou une annonce n'en demande pas plus.
    MAX_TEXTE    = 3_000
    # Citation maximale autorisée dans un résumé, en mots.
    MAX_CITATION = 15
    # Sources officielles : ce qu'elles publient invite par nature à agir.
    SOURCES_OPPORTUNITES = %w[jeveuxaider agenda_nancy formation transentreprise].freeze

    CATEGORIES = ::Opportunity::CATEGORIES

    SCHEMA = {
      type: "object",
      properties: {
        type:       { type: "string", enum: Veille::Candidate::ITEM_TYPES },
        categorie:  { type: "string", enum: CATEGORIES },
        commune:    { type: "string" },
        date_debut: { type: "string" },
        date_fin:   { type: "string" },
        regime:     { type: "string" },
        resume:     { type: "string" },
        confiance:  { type: "integer", minimum: 0, maximum: 100 },
        motif:      { type: "string" }
      },
      required: %w[type categorie commune date_debut date_fin regime resume confiance motif],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~TXT.freeze
      Tu es assistant éditorial de Déclic, plateforme d'engagement citoyen du Grand Nancy. On te donne un élément repéré sur une source publique (mission de bénévolat, événement d'agenda, formation, annonce de cession d'entreprise, article de presse). Tu le classes et tu le résumes. Un humain relira tout.

      RÈGLE ÉDITORIALE — le critère qui décide du type :
      - « opportunite » : le contenu invite à agir (s'inscrire, venir, candidater, rejoindre, reprendre une activité). Il a une date, des horaires, ou un régime permanent (« ouvert toute l'année »), et un moyen d'agir.
      - « belle_histoire » : un récit inspirant sur une personne ou un collectif, SANS horaires ni appel à l'action directe. Un article qui raconte un parcours est une belle histoire ; une annonce d'événement n'en est jamais une.

      CATÉGORIES (clé à renvoyer) : ecologiser (environnement, nature, énergie, réemploi), entreprendre (création, reprise, cession d'entreprise, emploi indépendant), rencontres (événements, conférences, échanges, vie de quartier), formation (se former, métiers, apprentissage), benevolat (s'engager, bénévolat, solidarité). Pour une belle histoire, choisis la catégorie dont elle est la plus proche.

      COMMUNE : la commune d'ancrage, parmi celles du Grand Nancy, telle que le texte la donne. Chaîne vide si le texte ne la donne pas ou si le lieu est hors du Grand Nancy. Tu ne la devines pas depuis le nom de la source.

      DATES : date_debut et date_fin au format AAAA-MM-JJ, uniquement si le texte les donne. Pas de date : chaînes vides, et « regime » dit en quelques mots le régime (« Ouvert toute l'année », « Sur rendez-vous »…) ; sinon regime est vide.

      RÉSUMÉ : exactement deux phrases, en français, reformulées avec tes propres mots. Tu ne recopies pas le texte source : au plus 15 mots consécutifs identiques à la source, et seulement pour une citation indispensable. Ni emoji, ni emphase, ni formule d'accroche. Les noms propres, lieux, dates et chiffres se reprennent tels quels.

      confiance (0-100) : ta certitude sur le type, la catégorie et la commune ENSEMBLE. motif : une phrase qui dit ce qui t'a fait trancher, ou ce qui manque.

      Réponds UNIQUEMENT par l'objet JSON demandé.
    TXT

    # Pur : paramètres de requête, sans réseau.
    def self.prompt_for(title:, text:, origin: nil, commune: nil, starts_on: nil, ends_on: nil, schedule_text: nil)
      lignes = ["Titre : #{title.to_s.strip}"]
      lignes << "Source : #{Veille::Candidate.origine_label(origin)}" if origin.present?
      lignes << "Commune indiquée par la source : #{commune}"        if commune.present?
      lignes << "Début : #{starts_on}" if starts_on
      lignes << "Fin : #{ends_on}"     if ends_on
      lignes << "Régime : #{schedule_text}" if schedule_text.present?
      lignes << ""
      lignes << "Texte récupéré :"
      lignes << text.to_s.squish.slice(0, MAX_TEXTE)

      json_schema_params(system: SYSTEM_PROMPT, user: lignes.join("\n"), schema: SCHEMA, max_tokens: MAX_TOKENS)
    end

    # Interroge le modèle, applique la réponse au candidat et l'enregistre.
    # Lève AnthropicClient::Error ou AiPass::ParseError : l'appelant décide.
    def enrich(candidate, today: Date.current)
      result = run(self.class.prompt_for(
        title: candidate.title, text: candidate.full_text.presence || candidate.excerpt, origin: candidate.origin,
        commune: candidate.commune, starts_on: candidate.starts_on, ends_on: candidate.ends_on,
        schedule_text: candidate.schedule_text
      ), candidate: candidate)
      apply(candidate, result, today: today)
      candidate
    end

    # Applique la réponse du modèle au candidat. Public et sans réseau : c'est là
    # que vivent les règles de classification et d'élimination, testées à part.
    def apply(candidate, result, today: Date.current)
      type = result["type"].to_s
      type = "opportunite" if SOURCES_OPPORTUNITES.include?(candidate.origin) && candidate.item_type != "belle_histoire"
      type = candidate.item_type.presence || "opportunite" unless Veille::Candidate::ITEM_TYPES.include?(type)

      commune = Veille::GrandNancy.canonique(result["commune"]) || Veille::GrandNancy.canonique(candidate.commune)
      debut   = parse_date(result["date_debut"]) || candidate.starts_on
      fin     = parse_date(result["date_fin"])   || candidate.ends_on
      categorie = result["categorie"].to_s
      categorie = candidate.declic_category.presence || "rencontres" unless CATEGORIES.include?(categorie)
      categorie = candidate.declic_category if candidate.declic_category.present? && type == "opportunite" &&
                                               SOURCES_OPPORTUNITES.include?(candidate.origin)

      attrs = {
        item_type: type, declic_category: categorie, commune: commune || candidate.commune,
        starts_on: debut, ends_on: fin,
        schedule_text: (debut || fin ? nil : (result["regime"].presence || candidate.schedule_text)),
        score: Integer(result["confiance"], exception: false)&.clamp(0, 100),
        reason: result["motif"].to_s.strip.presence, category: (type == "belle_histoire" ? "belle_histoire" : "autre"),
        qualified_at: Time.current, enriched_at: Time.current
      }
      resume = result["resume"].to_s.squish
      if self.class.copie_excessive?(resume, candidate.full_text.to_s + " " + candidate.title.to_s)
        attrs[:summary] = nil
        attrs[:status]  = "a_verifier"
        attrs[:reason]  = "Résumé trop proche de la source (plus de #{MAX_CITATION} mots d'affilée) : à réécrire. #{attrs[:reason]}".squish
      else
        attrs[:summary] = resume.presence
      end

      if commune.nil?
        attrs[:discard_reason] = "Hors Grand Nancy ou commune introuvable"
        attrs[:status] = "ecarte"
      elsif (fin || debut)&.<(today)
        attrs[:discard_reason] = "Événement passé"
        attrs[:status] = "ecarte"
      end

      candidate.update!(attrs)
    end

    # Vrai si `resume` reprend plus de MAX_CITATION mots consécutifs de `source`
    # (comparaison sans accents ni ponctuation).
    def self.copie_excessive?(resume, source, max: MAX_CITATION)
      r = Veille::Text.normalize(resume).split
      s = Veille::Text.normalize(source).split
      return false if r.size <= max || s.size <= max

      fenetres = s.each_cons(max + 1).to_set
      r.each_cons(max + 1).any? { |f| fenetres.include?(f) }
    end

    private

    def parse_date(valeur)
      valeur.to_s.strip.empty? ? nil : Date.iso8601(valeur.to_s.strip)
    rescue Date::Error
      nil
    end
  end
end
