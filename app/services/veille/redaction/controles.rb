# frozen_string_literal: true

module Veille
  module Redaction
    # Contrôle, en code, qu'un brouillon de belle histoire respecte la règle
    # éditoriale : un récit, sans horaires ni appel à l'action, sans contact, sans
    # citation ni chiffre qui ne vienne de la source, sans copie de la source.
    # Le prompt le demande au modèle ; ici on le vérifie.
    #
    # Fonction pure : aucun accès base ni réseau.
    #
    #   Controles.verifier(brouillon, source: texte_envoye_au_modele, manques: [...])
    #   # => Resultat(bloquants: [Constat], avertissements: [Constat])
    #
    # Un bloquant interdit de valider le brouillon tel quel (le candidat passe en
    # « à vérifier ») ; un avertissement s'affiche seulement.
    module Controles
      Constat  = Struct.new(:code, :message, keyword_init: true)
      Resultat = Struct.new(:bloquants, :avertissements, keyword_init: true) do
        def bloque? = bloquants.any?
        def propre? = bloquants.empty? && avertissements.empty?
        def codes   = bloquants.map(&:code) + avertissements.map(&:code)

        def as_json(*)
          { "bloquants" => bloquants.map { |c| { "code" => c.code, "message" => c.message } },
            "avertissements" => avertissements.map { |c| { "code" => c.code, "message" => c.message } } }
        end

        # Relit ce que as_json a écrit (colonne draft_controles).
        def self.depuis_json(h)
          h = h.to_h
          new(bloquants: Array(h["bloquants"]).map { |c| Constat.new(code: c["code"], message: c["message"]) },
              avertissements: Array(h["avertissements"]).map { |c| Constat.new(code: c["code"], message: c["message"]) })
        end
      end

      MOTS_MIN = 90
      MOTS_MAX = 160

      JOURS = "lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche"

      HORAIRE = /(?<![\d,.])(?:[01]?\d|2[0-3])\s?(?:h|:)\s?[0-5]\d\b|(?<![\d,.])(?:[01]?\d|2[0-3])\s?h\b|\b\d{1,2}\s?heures?\b/i
      HORAIRE_RECURRENT = /\b(?:tous\s+les|chaque)\s+(?:#{JOURS})s?\b/i

      APPEL_A_AGIR = /
        \b(?:inscri(?:vez|s|ptions?\s+(?:ouvertes?|obligatoires?|gratuites?))|rejoignez|rejoins|venez|viens|r[ée]servez|
        contactez|appelez|participez|candidatez|postulez|cliquez|[ée]crivez|abonnez|soutenez|devenez|engagez-vous|
        d[ée]couvrez|retrouvez-(?:le|la|les|nous)|rendez-vous\s+(?:au|à|a\s+la|sur)|
        n['’]h[ée]sitez\s+pas|pour\s+(?:s['’]inscrire|participer|nous\s+rejoindre|en\s+savoir\s+plus))\b
      /xi

      URL       = %r{https?://|\bwww\.|\b[\w-]+\.(?:fr|com|org|eu|net|asso)\b}i
      EMAIL     = /[\w.+-]+@[\w-]+\.\w+/
      TELEPHONE = /(?<!\d)(?:\+33\s?|0)[1-9](?:[\s.\-]?\d{2}){4}(?!\d)/

      CITATION = /«\s*(.+?)\s*»|“\s*(.+?)\s*”|"\s*(.+?)\s*"/m
      NOMBRE   = /\d+(?:[   .,]\d+)*/

      module_function

      def verifier(brouillon, source:, manques: [])
        texte = brouillon.to_s
        bloquants = []
        bloquants << constat("horaire", "Un horaire figure dans le récit : « #{extrait(texte, HORAIRE)} ».") if texte.match?(HORAIRE)
        if texte.match?(HORAIRE_RECURRENT)
          bloquants << constat("horaire", "Une récurrence figure dans le récit : « #{extrait(texte, HORAIRE_RECURRENT)} ».")
        end
        if texte.match?(APPEL_A_AGIR)
          bloquants << constat("appel_a_agir", "Appel à l'action : « #{extrait(texte, APPEL_A_AGIR)} ». Un récit raconte, il n'invite pas.")
        end
        contacts(texte).each { |c| bloquants << constat("contact", "Contact dans le récit (#{c}).") }
        citations_absentes(texte, source).each { |c| bloquants << constat("citation_absente", "Citation absente de la source : « #{c} ».") }
        nombres_absents(texte, source).each { |n| bloquants << constat("chiffre_absent", "Chiffre absent de la source : #{n}.") }
        if Veille::Text.copie_excessive?(texte, source)
          bloquants << constat("copie_excessive",
                               "Plus de #{Veille::Text::MAX_CITATION} mots d'affilée repris de la source : à réécrire.")
        end

        Resultat.new(bloquants: bloquants.uniq { |c| [c.code, c.message] }, avertissements: avertissements(texte, manques))
      end

      def avertissements(texte, manques)
        n = Veille::Text.words(texte).size
        liste = []
        liste << constat("longueur", "#{n} mots : visé entre #{MOTS_MIN} et #{MOTS_MAX}.") unless (MOTS_MIN..MOTS_MAX).cover?(n)
        manquants = Array(manques).map(&:to_s).reject(&:blank?)
        liste << constat("champs_manquants", "Informations absentes de la source : #{manquants.join(', ')}.") if manquants.any?
        liste
      end

      def contacts(texte)
        trouves = []
        trouves << "adresse web" if texte.match?(URL)
        trouves << "e-mail"      if texte.match?(EMAIL)
        trouves << "téléphone"   if texte.match?(TELEPHONE)
        trouves
      end

      def citations_absentes(texte, source)
        cible = Veille::Text.normalize(source)
        texte.scan(CITATION).map { |g| g.compact.first.to_s }.reject do |citation|
          norme = Veille::Text.normalize(citation)
          norme.empty? || cible.include?(norme)
        end
      end

      def nombres_absents(texte, source)
        connus = source.to_s.scan(NOMBRE).to_set { |n| chiffres(n) }
        # Horaires et téléphones ont leur propre constat : on n'en redouble pas les chiffres.
        texte = texte.gsub(HORAIRE, " ").gsub(TELEPHONE, " ")
        texte.scan(NOMBRE).reject { |n| connus.include?(chiffres(n)) }.map(&:strip).uniq
      end

      # « 1 200 » et « 1200 » sont le même nombre.
      def chiffres(nombre) = nombre.gsub(/[^\d]/, "")

      def extrait(texte, motif) = texte[motif].to_s.squish

      def constat(code, message) = Constat.new(code: code, message: message)
    end
  end
end
