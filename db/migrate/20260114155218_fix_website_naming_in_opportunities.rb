class FixWebsiteNamingInOpportunities < ActiveRecord::Migration[7.0]
  def change
    # Si vous n'avez pas encore de colonne source_url
    unless column_exists?(:opportunities, :source_url)
      add_column :opportunities, :source_url, :string
    end

    # On s'assure que website_url est le champ principal
    unless column_exists?(:opportunities, :website_url)
      add_column :opportunities, :website_url, :string
    end
  end
end
