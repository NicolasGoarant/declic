class AddTagsToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :tags, :string
  end
end
