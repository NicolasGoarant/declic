# Articles de presse écartés à la main : on ne garde que l'URL, pour ne plus les proposer.
# Table à part : aucun candidat n'est créé, la presse reste sans stockage de contenu.
class CreateVeillePresseEcartees < ActiveRecord::Migration[7.2]
  def change
    create_table :veille_presse_ecartees do |t|
      t.string :url, null: false
      t.timestamps
    end
    add_index :veille_presse_ecartees, :url, unique: true
  end
end
