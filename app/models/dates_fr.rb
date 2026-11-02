# Dates en français, écrites ici et nulle part ailleurs côté Ruby (le pendant JS : app/javascript/dates_fr.js).
#   complete(date)  → « dimanche 1er novembre 2026 »   (quand la place le permet)
#   abregee(date)   → « dim. 1er nov. 2026 »           (place contrainte : badge, ligne de liste)
# « 1er » pour le premier du mois, sinon le jour sans zéro initial.
module DatesFr
  JOURS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
  JOURS_ABREGES = %w[dim. lun. mar. mer. jeu. ven. sam.].freeze
  MOIS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze
  MOIS_ABREGES = %w[janv. févr. mars avr. mai juin juil. août sept. oct. nov. déc.].freeze

  module_function

  def jour(date) = date.day == 1 ? "1er" : date.day.to_s

  def complete(date, annee: true)
    [ JOURS[date.wday], jour(date), MOIS[date.month - 1], (date.year if annee) ].compact.join(" ")
  end

  def abregee(date, annee: true)
    [ JOURS_ABREGES[date.wday], jour(date), MOIS_ABREGES[date.month - 1], (date.year if annee) ].compact.join(" ")
  end
end
