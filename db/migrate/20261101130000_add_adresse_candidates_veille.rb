class AddAdresseCandidatesVeille < ActiveRecord::Migration[7.2]
  def change
    add_column :veille_candidates, :adresse, :string
  end
end
