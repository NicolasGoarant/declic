class AddFicheFieldsToOpportunities < ActiveRecord::Migration[7.2]
  # Champs de la future fiche Opportunité (maquette declic-maquette-fiche-opportunite-v1).
  # json et non jsonb : la base de dev est en SQLite, la production en Postgres.
  # start_date / end_date (chaînes) restent en place jusqu'à une version de transition.
  def change
    add_column :opportunities, :audience, :text
    add_column :opportunities, :programme, :json
    add_column :opportunities, :starts_on, :date
    add_column :opportunities, :ends_on, :date
    add_column :opportunities, :start_time, :time
    add_column :opportunities, :end_time, :time
    add_index :opportunities, :starts_on
    add_index :opportunities, :ends_on
  end
end
