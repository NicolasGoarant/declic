# db/migrate/*_add_virage_fields_to_opportunities.rb
class AddVirageFieldsToOpportunities < ActiveRecord::Migration[7.2]
  def change
    change_table :opportunities, bulk: true do |t|
      # Carrière / virage
      t.string  :audience_level
      t.string  :career_outcome
      t.text    :skills              # CSV "gestion de projet, dataviz"
      t.string  :credential          # "Certificat", "RNCP", etc.
      t.boolean :mentorship,         default: false, null: false
      t.boolean :alumni_network,     default: false, null: false
      t.boolean :hiring_partners,    default: false, null: false

      # Logistique
      t.string  :format              # présentiel / distanciel / hybride
      t.string  :schedule            # soir/week-end / intensif / continu
      t.integer :duration_weeks
      t.datetime :application_deadline
      t.string  :selectivity_level   # ouvert / dossier / sélectif
      t.text    :prerequisites

      # Économie / accès
      t.decimal :cost_eur, precision: 10, scale: 2
      t.boolean :is_free,            default: false, null: false
      t.boolean :scholarship_available, default: false, null: false
      t.text    :funding_options
      t.text    :accessibility

      # Impact
      t.text    :impact_domains      # CSV "climat, éducation"
      t.text    :impact_metric_hint  # "100 bénéficiaires/mois", etc.
    end
  end
end
