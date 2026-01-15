class AddCtaToOpportunities < ActiveRecord::Migration[7.2]
  def change
    add_column :opportunities, :cta_button_text, :string
    add_column :opportunities, :cta_button_url, :string
  end
end
