# frozen_string_literal: true
module Ingest
  class Normalizer
    # TEMP : on n'oblige que le title pour ne pas bloquer
    REQUIRED = %i[title starts_at].freeze

    POS = /atelier|d[ée]couverte|r[ée]union d'information|afterwork|petit[- ]d[ée]jeuner|visite|porte ouverte|webinaire|caf[ée] cr[ée]ateurs/i
    NEG = /congr[èe]s|salon pro|premium|gala|b2b/i

    def self.call(attrs)
      return nil if attrs.nil? # garde-fou
      a = attrs.symbolize_keys
      a[:timezone]  ||= "Europe/Paris"
      a[:category]  ||= "entreprendre"
      a[:mode]      ||= "presentiel"
      a[:intensity] ||= "decouverte"

      score = 0
      score += 2 if a[:title].to_s.match?(POS) || a[:summary].to_s.match?(POS)
      score -= 1 if a[:title].to_s.match?(NEG) || a[:summary].to_s.match?(NEG)
      a[:score] = score

      return nil unless REQUIRED.all? { |k| a[k].present? }
      a
    end
  end
end
