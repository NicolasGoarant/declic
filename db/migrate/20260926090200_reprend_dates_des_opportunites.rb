class ReprendDatesDesOpportunites < ActiveRecord::Migration[7.2]
  # Remplit starts_on / ends_on / start_time / end_time (et schedule_text pour le texte libre)
  # à partir de start_date / end_date et de starts_at / ends_at. Règles : ConversionDates.
  # Modèle local : la migration ne dépend ni des validations ni des callbacks de Opportunity.
  class OpportuniteMigration < ActiveRecord::Base
    self.table_name = "opportunities"
  end

  def up
    OpportuniteMigration.reset_column_information
    bilan = Hash.new(0)
    OpportuniteMigration.find_each do |o|
      conversion = ConversionDates.new(o)
      conversion.cas.each { |c| bilan[c] += 1 }
      o.update_columns(conversion.changements) if conversion.changements.any?
    end
    say "Dates des opportunités : #{bilan.sort.map { |c, n| "#{c} #{n}" }.join(', ').presence || 'rien à convertir'}"
  end

  def down
    OpportuniteMigration.reset_column_information
    # Seul schedule_text est une colonne ancienne modifiée par up : on retire le texte libre
    # qu'on y avait basculé. Les colonnes nouvelles disparaissent avec la migration précédente.
    OpportuniteMigration.find_each do |o|
      libres = [ o.start_date, o.end_date ].map { |v| v.to_s.strip }.reject { |v| v.empty? || ConversionDates.date_iso(v) }
      o.update_columns(schedule_text: nil) if o.schedule_text.present? && libres.include?(o.schedule_text)
    end
    OpportuniteMigration.update_all(starts_on: nil, ends_on: nil, start_time: nil, end_time: nil)
  end
end
