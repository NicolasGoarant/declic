class CreateOpportunities < ActiveRecord::Migration[7.2]
  def change
    create_table :opportunities do |t|
      t.string :title
      t.text :description
      t.string :category
      t.string :organization
      t.string :location
      t.string :contact_email
      t.string :contact_phone
      t.string :tags
      t.string :effort_level
      t.string :time_commitment
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.boolean :is_active

      t.timestamps
    end
  end
end
