# Réponses de l'étiquetage servant à calibrer le prompt. Table à part, sans lien avec
# veille_candidates : ces avis ne décident rien dans la file de relecture.
class CreateVeilleEtiquettes < ActiveRecord::Migration[7.2]
  def change
    create_table :veille_etiquettes do |t|
      t.string :ref, null: false
      t.string :avis
      t.text :commentaire
      t.timestamps
    end
    add_index :veille_etiquettes, :ref, unique: true
  end
end
