class AddMissingColumnsToOpportunities < ActiveRecord::Migration[7.1]
  def change
    add_column :opportunities, :summary,        :text    unless column_exists?(:opportunities, :summary)
    add_column :opportunities, :category,       :string  unless column_exists?(:opportunities, :category)
    add_column :opportunities, :intensity,      :string  unless column_exists?(:opportunities, :intensity)
    add_column :opportunities, :mode,           :string  unless column_exists?(:opportunities, :mode)
    add_column :opportunities, :starts_at,      :datetime unless column_exists?(:opportunities, :starts_at)
    add_column :opportunities, :ends_at,        :datetime unless column_exists?(:opportunities, :ends_at)
    add_column :opportunities, :timezone,       :string  unless column_exists?(:opportunities, :timezone)
    add_column :opportunities, :venue_name,     :string  unless column_exists?(:opportunities, :venue_name)
    add_column :opportunities, :address,        :string  unless column_exists?(:opportunities, :address)
    add_column :opportunities, :city,           :string  unless column_exists?(:opportunities, :city)
    add_column :opportunities, :organizer_name, :string  unless column_exists?(:opportunities, :organizer_name)
    add_column :opportunities, :url,            :string  unless column_exists?(:opportunities, :url)
    add_column :opportunities, :source,         :string  unless column_exists?(:opportunities, :source)
    add_column :opportunities, :tags,           :string  unless column_exists?(:opportunities, :tags)

    add_index :opportunities, :starts_at        unless index_exists?(:opportunities, :starts_at)
    add_index :opportunities, :city             unless index_exists?(:opportunities, :city)
    add_index :opportunities, :url, unique: true, length: 190  unless index_exists?(:opportunities, :url)
  end
end
