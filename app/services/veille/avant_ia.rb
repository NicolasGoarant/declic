# frozen_string_literal: true

module Veille
  # Ce que le code tranche AVANT tout appel IA (aucun jeton facturé) : un événement dont la date est déjà passée,
  # et les fiches de catalogue qui n'en font qu'une (voir Formations). Les candidats déjà passés par l'IA
  # (enriched_at) et ceux classés à la main (classement_manuel) ne sont jamais touchés.
  module AvantIa
    RAISON_PASSE = "Événement passé (filtre avant IA)"

    module_function

    # Date qui compte : la fin, ou le début à défaut. nil = pas de date, circuit normal.
    def date_de_reference(candidat) = candidat.ends_on || candidat.starts_on

    def passe?(candidat, today: Date.current)
      date = date_de_reference(candidat)
      !date.nil? && date < today
    end

    # Écarte (sans appel) ce qui est passé ou doublon ; rend { passes: n, doublons: n } et la file restante.
    def appliquer(file, today: Date.current, logger: Rails.logger)
      bilan = { passes: 0, doublons: 0 }
      restants = file.reject do |c|
        next false if c.classement_manuel?

        if passe?(c, today: today)
          c.update!(status: "ecarte", discard_reason: RAISON_PASSE)
          logger.info("[Veille] écarté avant IA ##{c.id} (#{c.origin}) : #{RAISON_PASSE} (#{date_de_reference(c)}), aucun appel facturé")
          bilan[:passes] += 1
          true
        end
      end
      restants, ecartes = Formations.regrouper(restants, logger: logger)
      bilan[:doublons] = ecartes
      [restants, bilan]
    end
  end
end
