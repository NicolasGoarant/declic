class AddSourceFieldsToOpportunities < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:opportunities, :source_name)
      add_column :opportunities, :source_name, :string
    end

    unless column_exists?(:opportunities, :source_url)
      add_column :opportunities, :source_url, :string
    end
  end
end
