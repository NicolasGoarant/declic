class AddScheduleFieldsToOpportunities < ActiveRecord::Migration[7.2]
  def change
    # Ajoute seulement ce qui manque (idempotent)
    add_column :opportunities, :starts_at,     :datetime unless column_exists?(:opportunities, :starts_at)
    add_column :opportunities, :ends_at,       :datetime unless column_exists?(:opportunities, :ends_at)
    add_column :opportunities, :schedule_text, :string   unless column_exists?(:opportunities, :schedule_text)
    add_column :opportunities, :external_url,  :string   unless column_exists?(:opportunities, :external_url)

    add_index :opportunities, :starts_at unless index_exists?(:opportunities, :starts_at)
    add_index :opportunities, :ends_at   unless index_exists?(:opportunities, :ends_at)
  end
end
