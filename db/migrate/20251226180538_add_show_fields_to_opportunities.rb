class AddShowFieldsToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :quote, :text
    add_column :opportunities, :quote_author, :string
    add_column :opportunities, :stat_1_number, :string
    add_column :opportunities, :stat_1_label, :string
    add_column :opportunities, :stat_2_number, :string
    add_column :opportunities, :stat_2_label, :string
    add_column :opportunities, :stat_3_number, :string
    add_column :opportunities, :stat_3_label, :string
    add_column :opportunities, :stat_4_number, :string
    add_column :opportunities, :stat_4_label, :string
    add_column :opportunities, :challenges, :text
  end
end
