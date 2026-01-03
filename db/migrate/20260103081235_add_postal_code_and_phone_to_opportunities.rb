class AddPostalCodeAndPhoneToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :postal_code, :string
    add_column :opportunities, :phone, :string
  end
end
