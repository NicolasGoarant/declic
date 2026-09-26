# Indicateur de complétude d'une fiche : part des champs que la nouvelle fiche affiche.
# Le modèle déclare `criteres_fiche` : { "Libellé" => vrai/faux }.
module FicheCompletude
  extend ActiveSupport::Concern

  def champs_manquants = criteres_fiche.reject { |_, rempli| rempli }.keys

  def completude
    criteres = criteres_fiche
    (100.0 * criteres.values.count(true) / criteres.size).round
  end
end
