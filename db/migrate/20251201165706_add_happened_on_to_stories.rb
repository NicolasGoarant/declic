class AddHappenedOnToStories < ActiveRecord::Migration[7.1]
  def change
    add_column :stories, :happened_on, :date
  end
end
