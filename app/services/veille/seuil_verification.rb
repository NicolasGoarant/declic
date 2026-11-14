# frozen_string_literal: true

module Veille
  # Applique après coup (sans aucun appel IA) la règle « À vérifier » aux candidats déjà triés : un proposé dont le
  # score est sous le seuil (VEILLE_SEUIL_VERIF), ou dont le second avis (Sonnet) est resté illisible. Idempotent :
  # un candidat déplacé n'est plus « proposé ». Ni les écartés ni les classés à la main ne sont touchés.
  module SeuilVerification
    module_function

    # Rend { score_faible: [ids], second_avis_illisible: [ids] }.
    def appliquer(dry_run: false)
      seuil = AiEnricher.seuil_verification
      propose = Candidate.where(status: "pending", discard_reason: nil, classement_manuel: false).where.not(enriched_at: nil)
      illisibles = AppelIa.where(passe: "escalade", statut: "illisible").pluck(:candidate_id).uniq
      avec_ok = AppelIa.where(passe: "escalade", statut: "ok").pluck(:candidate_id).uniq
      sans_second = illisibles - avec_ok

      bilan = { score_faible: [], second_avis_illisible: [] }
      propose.find_each do |c|
        raison, cle =
          if sans_second.include?(c.id) then ["Second avis illisible", :second_avis_illisible]
          elsif c.score && c.score < seuil then ["Score faible (#{c.score})", :score_faible]
          end
        next unless raison

        bilan[cle] << c.id
        c.update!(status: "a_verifier", reason: "#{raison} : #{c.reason}".squish.slice(0, 500)) unless dry_run
      end
      bilan
    end
  end
end
