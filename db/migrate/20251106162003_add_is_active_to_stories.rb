class AddIsActiveToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :is_active, :boolean
  end
end
