# frozen_string_literal: true

module Veille
  # Nettoie les textes collectés de deux défauts de l'agenda :
  #  1. les mots relatifs à la date de consultation (« Aujourd'hui de 18h30 à 20h », « Ce soir à 18h ») :
  #     ils sont faux dès le lendemain. Le segment est réécrit avec la date absolue quand l'événement
  #     tient sur un seul jour (« Mercredi 16 décembre 2026 de 18h30 à 20h »), sinon le mot est simplement retiré ;
  #  2. les segments identiques consécutifs (« Conférence - Rencontre. Conférence - Rencontre. »).
  # Seuls les segments courts qui COMMENCENT par un mot relatif sont réécrits : une phrase de presse
  # (« Hier, le conseil a voté… ») n'est jamais touchée. Idempotent.
  module TextesRelatifs
    module_function

    JOURS = %w[lundi mardi mercredi jeudi vendredi samedi dimanche].freeze
    MOIS  = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

    MOTS = "aujourd['’]hui|demain|hier|ce\\s+soir|cette\\s+semaine|ce\\s+week-end"
    # « Aujourd'hui », « Ce soir de 20h à minuit », « Demain à 14h et 16h » : mot relatif, puis éventuellement l'horaire.
    SEGMENT_RELATIF = /\A(?:#{MOTS})(?:\s+(?:(?:à|de|dès|vers|entre|jusqu['’]à)\s+)?([^.]{1,50}))?\z/i
    MOT_SEUL        = /\A(?:#{MOTS})\z/i
    A_DES_RELATIFS  = /(?<![[:alpha:]])(?:#{MOTS})(?![[:alpha:]])/i

    # Vrai si le texte contient un mot relatif (détection large, pour l'audit).
    def relatif?(texte) = texte.to_s.match?(A_DES_RELATIFS)

    # Vrai si deux segments identiques se suivent (détection pour l'audit).
    def doublon?(texte) = segments(texte).each_cons(2).any? { |a, b| meme?(a, b) }

    def nettoyer(texte, starts_on: nil, ends_on: nil)
      return texte if texte.blank?

      un_jour = starts_on.present? && (ends_on.blank? || ends_on == starts_on)
      sortie = []
      segments(texte).each do |seg|
        seg = reecrire(seg, un_jour ? starts_on : nil)
        next if seg.blank?
        next if sortie.any? && meme?(sortie.last, seg)

        sortie << seg
      end
      sortie.join(". ")
    end

    def segments(texte) = texte.to_s.split(". ")

    def meme?(a, b) = a.to_s.squish.casecmp?(b.to_s.squish)

    # « Mercredi 16 décembre 2026 »
    def date_longue(date) = "#{JOURS[date.cwday - 1].capitalize} #{date.day} #{MOIS[date.month - 1]} #{date.year}"

    def reecrire(segment, date)
      s = segment.strip.chomp(".")
      return segment if s.length > 70
      return(date ? date_longue(date) : nil) if s.match?(MOT_SEUL)

      m = s.match(SEGMENT_RELATIF) or return segment
      reste = s.sub(/\A(?:#{MOTS})\s+/i, "")
      date ? "#{date_longue(date)} #{reste}" : reste.presence
    end
  end
end
