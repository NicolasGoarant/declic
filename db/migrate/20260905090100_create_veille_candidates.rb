class CreateVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    create_table :veille_candidates do |t|
      # Optionnel : une URL importée à la main peut ne se rattacher à
      # aucune source enregistrée.
      t.references :veille_source,
                   null:        true,
                   foreign_key: { to_table: :veille_sources, on_delete: :nullify }

      t.string :title
      t.text   :excerpt
      t.string :url, null: false
      t.date   :published_on

      # Tampon de travail uniquement : effacé dès qu'une Story est publiée
      # depuis ce candidat (voir Story#purge_veille_candidate_full_text).
      # Déclic ne constitue pas de base dérivée d'articles de presse.
      t.text :full_text

      # Enum applicatif : belle_histoire | autre. Nul tant que la passe A
      # de qualification n'a pas tourné.
      t.string   :category
      t.integer  :score
      t.string   :reason
      t.datetime :qualified_at

      # Enum applicatif : pending | retenu | ecarte | publie.
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :veille_candidates, :url, unique: true
    add_index :veille_candidates, :status
    add_index :veille_candidates, :score
  end
end
