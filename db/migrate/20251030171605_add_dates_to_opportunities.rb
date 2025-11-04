class AddDatesToOpportunities < ActiveRecord::Migration[7.1]
  def change
    # n’ajoute que si la colonne n’existe pas déjà (compatible SQLite / Postgres)
    add_column :opportunities, :starts_at, :datetime, precision: 6 unless column_exists?(:opportunities, :starts_at)
    add_column :opportunities, :ends_at,   :datetime, precision: 6 unless column_exists?(:opportunities, :ends_at)

    add_index :opportunities, :starts_at unless index_exists?(:opportunities, :starts_at)
    add_index :opportunities, :ends_at   unless index_exists?(:opportunities, :ends_at)
  end
end
