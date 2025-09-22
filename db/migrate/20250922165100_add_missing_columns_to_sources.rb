class AddMissingColumnsToSources < ActiveRecord::Migration[7.1]
  def change
    add_column :sources, :name, :string unless column_exists?(:sources, :name)
    add_column :sources, :kind, :integer, default: 0, null: false unless column_exists?(:sources, :kind)
    add_column :sources, :url, :string, null: false unless column_exists?(:sources, :url)
    add_column :sources, :active, :boolean, default: true unless column_exists?(:sources, :active)
    add_column :sources, :last_fetched_at, :datetime unless column_exists?(:sources, :last_fetched_at)
    add_column :sources, :success_rate, :float unless column_exists?(:sources, :success_rate)

    add_index :sources, :url, unique: true unless index_exists?(:sources, :url)
  end
end
