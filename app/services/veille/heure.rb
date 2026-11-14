# frozen_string_literal: true

module Veille
  # Une heure du jour, lue avec indulgence. Représentation unique des heures d'un candidat : colonne `time`
  # (Time du 1er janvier 2000, comme Opportunity#start_time / end_time et les champs <input type="time">),
  # donc aucune conversion à reporter à la validation. Les chaînes sont lues ici, une fois, à l'écriture.
  #
  #   Heure.lire("14:00") / "14h" / "14h30" / "9h00" / "9 h 05" / Time → Time.utc(2000, 1, 1, h, m)
  #   Heure.lire(nil) / "" → nil ; Heure.lire("bientôt") → nil, avec une trace dans le journal.
  module Heure
    FORMAT = /\A\s*(\d{1,2})\s*(?:h|:)\s*(\d{2})?\s*(?:min)?\s*\z/i

    module_function

    def lire(valeur)
      return nil if valeur.blank?
      return a_heure(valeur.hour, valeur.min) if valeur.respond_to?(:hour) && valeur.respond_to?(:min)

      m = valeur.to_s.match(FORMAT)
      h = m && m[1].to_i
      mn = m && m[2].to_i
      return a_heure(h, mn) if m && h <= 23 && mn <= 59

      Rails.logger.warn("[Veille::Heure] heure illisible ignorée : #{valeur.inspect}")
      nil
    end

    # « 14h » ou « 14h30 ».
    def afficher(heure)
      t = lire(heure) or return nil
      t.min.zero? ? "#{t.hour}h" : format("%dh%02d", t.hour, t.min)
    end

    def a_heure(h, mn) = Time.utc(2000, 1, 1, h, mn)
    private_class_method :a_heure
  end
end
