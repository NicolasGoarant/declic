# frozen_string_literal: true

module Taxonomie
  # Passage unique de l'ancienne catégorie « rencontres » à Pratiquer / Découvrir, à lancer juste après le
  # déploiement du code (rake taxonomie:recategoriser). Écrit directement en base : l'ancienne valeur ne
  # passe plus les validations. Les fiches listées dans FICHIER suivent la décision relue ; une fiche
  # absente du fichier (publiée depuis, ou autre base) suit sa famille. À supprimer après le passage en production.
  class Recategorisation
    ANCIENNE = "rencontres"
    FICHIER  = Rails.root.join("config/taxonomie/recategorisation_rencontrer_2026-11-01.json")
    REPLI    = "decouvrir"

    Changement = Data.define(:id, :titre, :vers, :origine)

    def initialize(decisions: JSON.parse(FICHIER.read))
      @decisions = decisions.to_h { |d| [ d["id"], d ] }
    end

    def changements
      Opportunity.where(category: ANCIENNE).order(:id).map do |fiche|
        decision = @decisions[fiche.id]
        if decision && decision["titre"] == fiche.title
          Changement.new(id: fiche.id, titre: fiche.title, vers: decision.fetch("vers"), origine: "décision relue")
        else
          vers = Veille::AiEnricher::CATEGORIE_PAR_FAMILLE[fiche.famille]
          Changement.new(id: fiche.id, titre: fiche.title, vers: vers || REPLI, origine: vers ? "famille" : "repli, à relire")
        end
      end
    end

    # Tout ou rien. Rend le bilan ; les horodatages ne bougent pas (rien n'a changé pour le lecteur).
    def appliquer
      ApplicationRecord.transaction do
        liste = changements
        liste.group_by(&:vers).each { |vers, lot| Opportunity.where(id: lot.map(&:id)).update_all(category: vers) }
        { fiches: liste, candidats: migrer_candidats }
      end
    end

    private

    # Un candidat publié suit sa fiche, les autres leur famille : tous gardent une catégorie valide.
    def migrer_candidats
      lignes = Veille::Candidate.where(declic_category: ANCIENNE).left_joins(:opportunity)
                                .pluck("veille_candidates.id", "veille_candidates.famille", "opportunities.category")
      lignes.group_by { |_, famille, categorie| categorie_valide(categorie) || Veille::AiEnricher::CATEGORIE_PAR_FAMILLE[famille] || REPLI }
            .each { |vers, lot| Veille::Candidate.where(id: lot.map(&:first)).update_all(declic_category: vers) }
      lignes.size
    end

    def categorie_valide(categorie) = (categorie if Opportunity::CATEGORIES.include?(categorie))
  end
end
