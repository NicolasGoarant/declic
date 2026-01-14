class AddAuthorToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :source_author, :string
  end
end
