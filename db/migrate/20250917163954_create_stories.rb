class CreateStories < ActiveRecord::Migration[7.2]
  def change
    create_table :stories do |t|
      t.string :title
      t.string :slug
      t.text :chapo
      t.text :body
      t.text :description
      t.string :image_url
      t.string :source_url
      t.string :source_name
      t.string :location
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
