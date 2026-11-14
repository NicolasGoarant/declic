# frozen_string_literal: true

module Veille
  # Fiches de catalogue d'organismes de formation (origine « formation », ex. Pôle formation UIMM Lorraine).
  #  - contenu_utile : la page est lue depuis son menu ; seul le texte après le fil d'Ariane est envoyé à l'IA
  #    (sinon le résumé reprend la navigation du site).
  #  - regrouper : une candidature par formation. Même organisme + même titre de base (le titre sans la suite
  #    « Personnel … » qui décline la même fiche) et aucune session datée distincte = quasi-doublons ; le premier
  #    (de préférence non écarté) reste, les autres sont écartés « Doublon de #id », sans appel IA.
  module Formations
    ORIGINE = "formation"
    FIL_ARIANE = /breadcrumb\s+Accueil\s+/i
    DECLINAISON = /\s+(?:-\s+)?Personnel\b.*\z/i

    module_function

    def contenu_utile(texte)
      t = texte.to_s
      i = t.index(FIL_ARIANE)
      i ? t[(i + t[FIL_ARIANE].length)..].to_s : t
    end

    def titre_de_base(titre)
      Veille::Text.normalize(titre.to_s.sub(DECLINAISON, "").split(" - ").first)
    end

    def organisme(candidat) = candidat.source&.name.to_s.strip

    def cle(candidat) = [organisme(candidat), titre_de_base(candidat.title), candidat.starts_on, candidat.ends_on]

    def raison_doublon(id) = "Doublon de ##{id}"

    # Paires [doublon, référence] parmi tous les candidats de formation (les écrits à la main sont laissés).
    def doublons
      tous = Veille::Candidate.where(origin: ORIGINE).includes(:source).order(:id).to_a
      tous.group_by { |c| cle(c) }.values.select { |g| g.size > 1 }.flat_map do |groupe|
        reference = reference_pour(groupe)
        (groupe - [reference]).reject(&:classement_manuel?).map { |c| [c, reference] }
      end
    end

    # `file` : candidats pas encore passés par l'IA. Rend [file sans les doublons, nombre écartés].
    def regrouper(file, logger: Rails.logger)
      ids = file.map(&:id)
      a_ecarter = doublons.select { |c, _| ids.include?(c.id) }
      a_ecarter.each do |c, reference|
        c.update!(status: "ecarte", discard_reason: raison_doublon(reference.id))
        logger.info("[Veille] écarté avant IA ##{c.id} : #{c.discard_reason}, aucun appel facturé")
      end
      retires = a_ecarter.map { |c, _| c.id }
      [file.reject { |c| retires.include?(c.id) }, retires.size]
    end

    def reference_pour(groupe) = groupe.min_by { |c| [c.ecarte? ? 1 : 0, c.id] }
  end
end
