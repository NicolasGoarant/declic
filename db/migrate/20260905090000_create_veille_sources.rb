class CreateVeilleSources < ActiveRecord::Migration[7.2]
  def change
    create_table :veille_sources do |t|
      t.string   :name, null: false
      # Enum applicatif : presse | magazine_municipal | media_public.
      # Stocké en string pour rester portable SQLite (dev/test) / Postgres (prod).
      t.string   :kind, null: false
      t.string   :url,  null: false
      t.boolean  :active, null: false, default: true
      # Renseigné le jour où un collecteur existera. Ce chantier n'en a aucun :
      # l'entrée se fait uniquement par rake veille:import.
      t.datetime :last_collected_at

      t.timestamps
    end

    add_index :veille_sources, :name, unique: true
    add_index :veille_sources, :active
  end
end
