# Thématique d'une Belle Histoire : une des catégories d'opportunité (facultatif). Elle oriente
# « Des opportunités pour avoir ton déclic » sur la fiche de l'histoire.
class AddThematiqueToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :thematique, :string
  end
end
