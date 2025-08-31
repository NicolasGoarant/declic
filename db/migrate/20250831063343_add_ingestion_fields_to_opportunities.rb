class AddIngestionFieldsToOpportunities < ActiveRecord::Migration[7.1]
  def change
    add_column :opportunities, :source, :string
    add_column :opportunities, :source_url, :string
    add_column :opportunities, :external_id, :string
    add_column :opportunities, :address, :string
    add_column :opportunities, :city, :string
    add_column :opportunities, :postcode, :string
    add_column :opportunities, :website, :string
    add_column :opportunities, :starts_at, :datetime
    add_column :opportunities, :ends_at, :datetime
    add_column :opportunities, :published_at, :datetime
    add_column :opportunities, :expires_at, :datetime
    add_column :opportunities, :raw_payload, :text

    add_index :opportunities, [:source, :external_id], unique: true
  end
end

