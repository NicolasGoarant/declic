# frozen_string_literal: true

module Veille
  # Lit dans un texte français ce qui date un événement : début, fin, heures et périodicité
  # (« tous les samedis et dimanches »). Pur et prudent : il ne rend que ce que le texte dit, sans rien deviner.
  # Sert de repli quand ni la source structurée ni l'IA n'ont donné de date.
  #
  #   « Jusqu'au 28 mars 2027, tous les samedis et dimanches de 11h à 12h »
  #     → fin 28/03/2027, 11h → 12h, périodicité « tous les samedis et dimanches »
  #   « Du samedi 27 au dimanche 29 novembre » → 27/11 → 29/11 (année : celle de la référence, ou la suivante)
  #   « Dimanche 13 décembre à 14h30 »         → 13/12, 14h30
  #
  # L'année manquante est celle de `reference` (date de publication, à défaut du jour), ou la suivante si le jour
  # est déjà passé à cette date : même règle que le prompt de l'enrichissement.
  module DatesFrancais
    Resultat = Struct.new(:starts_on, :ends_on, :start_time, :end_time, :periodicite, keyword_init: true) do
      def vide? = to_h.values.all?(&:nil?)
    end

    MOIS = {
      "janvier" => 1, "fevrier" => 2, "mars" => 3, "avril" => 4, "mai" => 5, "juin" => 6, "juillet" => 7,
      "aout" => 8, "septembre" => 9, "octobre" => 10, "novembre" => 11, "decembre" => 12
    }.freeze
    JOURS = %w[lundi mardi mercredi jeudi vendredi samedi dimanche].freeze

    MOIS_RE  = MOIS.keys.join("|")
    JOUR_RE  = "1er|\\d{1,2}"
    NOM_JOUR = "(?:#{JOURS.join('|')})\\s+"
    ANNEE    = "(20\\d{2})"
    DATE     = "(#{JOUR_RE})(?:\\s+(#{MOIS_RE}))?(?:\\s+#{ANNEE})?"
    DATE_M   = "(#{JOUR_RE})\\s+(#{MOIS_RE})(?:\\s+#{ANNEE})?"

    RANGE   = /\bdu\s+(?:#{NOM_JOUR})?#{DATE}\s+au\s+(?:#{NOM_JOUR})?#{DATE_M}/
    ET      = /\b(?:les\s+)?(#{JOUR_RE})\s+et\s+(#{JOUR_RE})\s+(#{MOIS_RE})(?:\s+#{ANNEE})?/
    JUSQUAU = /\bjusqu['’]?\s?(?:au|a)\s+(?:#{NOM_JOUR})?#{DATE_M}/
    DEPUIS  = /\b(?:a partir du|des le|depuis le)\s+(?:#{NOM_JOUR})?#{DATE_M}/
    SIMPLE  = /\b(?:le\s+)?(?:#{NOM_JOUR})?#{DATE_M}/

    HEURE   = "(\\d{1,2})\\s?h\\s?(\\d{2})?"
    DE_A    = /\bde\s+#{HEURE}\s+(?:a|à)\s+#{HEURE}/
    TIRET   = /\b#{HEURE}\s?[-–]\s?#{HEURE}/
    A_HEURE = /\b(?:a|à|dès|des)\s+#{HEURE}/
    SEULE   = /\b#{HEURE}/

    PLURIELS = "lundis?|mardis?|mercredis?|jeudis?|vendredis?|samedis?|dimanches?|jours?|semaines?|mois|soirs?|matins?"
    TOUS_LES = /\b(?:tous|toutes|chaque)\s+(?:les\s+)?(?:(?:#{PLURIELS})(?:\s*(?:,|et)\s*)?)+/
    DU_AU    = /\bdu\s+(?:#{JOURS.join('|')})\s+au\s+(?:#{JOURS.join('|')})\b/
    LES_JOURS = /\bles\s+(?:(?:lundis|mardis|mercredis|jeudis|vendredis|samedis|dimanches)(?:\s*(?:,|et)\s*)?)+/

    module_function

    def analyser(texte, reference: Date.current)
      t = normaliser(texte)
      return Resultat.new if t.blank?

      debut, fin = dates(t, reference)
      h1, h2 = heures(t)
      Resultat.new(starts_on: debut, ends_on: fin, start_time: h1, end_time: h2, periodicite: periodicite(t))
    end

    def normaliser(texte)
      I18n.transliterate(texte.to_s.downcase.tr("’", "'")).squish
    end

    def dates(t, reference)
      if (m = t.match(RANGE))
        j1, m1, a1, j2, m2, a2 = m.captures
        fin = date(j2, m2, a2, reference)
        mois1 = m1 || m2
        debut = date(j1, mois1, a1 || (a2 if m1.nil? || m1 == m2), reference)
        debut = date(j1, mois1, (fin.year - 1).to_s, reference) if debut && fin && debut > fin && a1.nil?
        return [ debut, fin ]
      end
      if (m = t.match(ET))
        j1, j2, mo, a = m.captures
        return [ date(j1, mo, a, reference), date(j2, mo, a, reference) ]
      end
      fin   = (m = t.match(JUSQUAU)) && date(*m.captures.values_at(0, 1, 2), reference)
      debut = (m = t.match(DEPUIS))  && date(*m.captures.values_at(0, 1, 2), reference)
      return [ debut || nil, fin || nil ] if debut || fin

      m = t.match(SIMPLE) or return [ nil, nil ]
      [ date(m[1], m[2], m[3], reference), nil ]
    end

    # nil si la date n'existe pas (31 novembre).
    def date(jour, mois, annee, reference)
      jour = jour.to_s == "1er" ? 1 : jour.to_i
      mois = MOIS[mois] or return nil
      return Date.new(annee.to_i, mois, jour) if annee.present?

      d = Date.new(reference.year, mois, jour)
      d < reference ? Date.new(reference.year + 1, mois, jour) : d
    rescue Date::Error
      nil
    end

    def heures(t)
      if (m = t.match(DE_A) || t.match(TIRET))
        return [ heure(m[1], m[2]), heure(m[3], m[4]) ]
      end
      m = t.match(A_HEURE) || t.match(SEULE) or return [ nil, nil ]
      [ heure(m[1], m[2]), nil ]
    end

    def heure(h, min)
      h = h.to_i
      return nil if h > 23

      Time.utc(2000, 1, 1, h, min.to_i)
    end

    def periodicite(t)
      phrase = t[TOUS_LES] || t[DU_AU] || t[LES_JOURS]
      phrase&.squish&.sub(/\s*(?:,|et)\z/, "")
    end
  end
end
