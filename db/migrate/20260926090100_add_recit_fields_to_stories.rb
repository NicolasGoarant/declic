class AddRecitFieldsToStories < ActiveRecord::Migration[7.2]
  # Champs de la future fiche Belle Histoire. Les colonnes highlights_* restent en place.
  def change
    add_column :stories, :venue_name, :string
    add_column :stories, :discover_url, :string
    add_column :stories, :quote_author, :string
    add_column :stories, :points_forts, :json
    add_column :stories, :source_published_on, :date
  end
end
