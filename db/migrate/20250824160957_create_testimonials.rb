class CreateTestimonials < ActiveRecord::Migration[7.2]
  def change
    create_table :testimonials do |t|
      t.string :name
      t.integer :age
      t.string :role
      t.text :story
      t.string :image_url

      t.timestamps
    end
  end
end
