# L'outil d'étiquetage (calibration du prompt v5) a rempli son rôle : on retire sa table.
# Les traces de la calibration restent dans config/veille/etiquetage_2026-10-31.json et docs/analyse-corpus/.
class DropVeilleEtiquettes < ActiveRecord::Migration[7.2]
  def change
    drop_table :veille_etiquettes do |t|
      t.string :ref, null: false
      t.string :avis
      t.text :commentaire
      t.timestamps
      t.index :ref, unique: true
    end
  end
end
