class AddSlugToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :slug, :string
    add_index :opportunities, :slug, unique: true
  end
end
