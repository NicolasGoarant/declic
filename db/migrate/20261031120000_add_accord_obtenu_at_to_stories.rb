# Accord de la personne racontée. Une fiche issue de la veille (veille_candidate_id)
# ne peut pas être mise en ligne tant qu'il n'est pas obtenu (voir Story).
class AddAccordObtenuAtToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :accord_obtenu_at, :datetime
  end
end
