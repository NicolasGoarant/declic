class AddImageUrlToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :image_url, :string
  end
end
