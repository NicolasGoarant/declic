# Tri des listes admin sur la colonne « Fiche » (pourcentage de complétude).
# La complétude est calculée en Ruby : le tri se fait donc en mémoire, après la requête
# (quelques centaines de fiches au plus).
module TriParCompletude
  extend ActiveSupport::Concern

  private

  # [tri, sens] issus de ?tri=fiche&sens=asc|desc ; tri nil = ordre naturel de la liste.
  def tri_fiche_params
    return [ nil, nil ] unless params[:tri] == "fiche"

    [ "fiche", params[:sens] == "desc" ? "desc" : "asc" ]
  end

  # sort_by n'est pas stable : l'ordre d'origine (récent d'abord) départage les égalités.
  def trier_par_completude(relation, tri, sens)
    return relation unless tri == "fiche"

    fiches = relation.to_a.each_with_index.sort_by { |fiche, rang| [ fiche.completude, rang ] }.map(&:first)
    sens == "desc" ? fiches.reverse : fiches
  end
end
