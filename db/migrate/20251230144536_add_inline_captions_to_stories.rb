class AddInlineCaptionsToStories < ActiveRecord::Migration[7.2]
  def change
    # Ajouter les colonnes inline_caption uniquement si elles n'existent pas déjà
    add_column :stories, :inline_caption_1, :string unless column_exists?(:stories, :inline_caption_1)
    add_column :stories, :inline_caption_2, :string unless column_exists?(:stories, :inline_caption_2)
    add_column :stories, :inline_caption_3, :string unless column_exists?(:stories, :inline_caption_3)
  end
end
