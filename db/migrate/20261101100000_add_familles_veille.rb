class AddFamillesVeille < ActiveRecord::Migration[7.2]
  def change
    add_column :veille_candidates, :famille, :string
    add_column :veille_candidates, :role_public, :string
    add_column :veille_candidates, :zone, :string

    # Nulle sur les fiches existantes : elles restent affichées.
    add_column :opportunities, :famille, :string
    add_index :opportunities, :famille
  end
end
