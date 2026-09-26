class AddPhotosOrder < ActiveRecord::Migration[7.2]
  # Ordre de la galerie : liste d'ids d'attachments (la première = photo de couverture).
  # ActiveStorage n'a pas de position ; un json évite toute table supplémentaire.
  def change
    add_column :opportunities, :photos_order, :json
    add_column :stories, :photos_order, :json
  end
end
