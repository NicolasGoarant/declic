# Un humain a posé le type (et la catégorie) du candidat : un nouveau tri IA ne les écrase plus.
class AddClassementManuelToVeilleCandidates < ActiveRecord::Migration[7.2]
  def change
    add_column :veille_candidates, :classement_manuel, :boolean, default: false, null: false
  end
end
