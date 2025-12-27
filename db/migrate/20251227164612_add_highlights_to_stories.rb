class AddHighlightsToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :highlights_title, :string
    add_column :stories, :highlights_text, :text
    add_column :stories, :highlights_items, :text
  end
end
