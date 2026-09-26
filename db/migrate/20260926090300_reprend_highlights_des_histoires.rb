class ReprendHighlightsDesHistoires < ActiveRecord::Migration[7.2]
  # highlights_items (une ligne = un point) -> points_forts [{icone, titre, texte}].
  # Les colonnes highlights_* restent en place : rien n'est perdu.
  class HistoireMigration < ActiveRecord::Base
    self.table_name = "stories"
  end

  def up
    HistoireMigration.reset_column_information
    HistoireMigration.where(points_forts: nil).find_each do |h|
      points = PointsForts.depuis_lignes(h.highlights_items)
      next if points.empty?

      say "Histoire ##{h.id} : #{points.size} points, seuls les #{PointsForts::MAX} premiers sont repris" if points.size > PointsForts::MAX
      h.update_columns(points_forts: points.first(PointsForts::MAX))
    end
  end

  def down
    HistoireMigration.reset_column_information
    HistoireMigration.update_all(points_forts: nil)
  end
end
