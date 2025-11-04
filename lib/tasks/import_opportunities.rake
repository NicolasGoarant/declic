require "csv"

namespace :declic do
  desc "Importe un CSV d'opportunités (idempotent) + rapport détaillé"
  task import_csv: :environment do
    path = ENV["CSV"] || "collector/opportunities_local.csv"
    dry  = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])

    unless File.exist?(path)
      puts "❌ CSV introuvable: #{path}"
      exit 1
    end

    created = 0
    updated = 0
    skipped_dup = 0
    errors = []

    CSV.foreach(path, headers: true, encoding: "UTF-8") do |row|
      h = row.to_h.symbolize_keys

      finder = {
        title:        h[:title].to_s.strip,
        organization: h[:organization].to_s.strip,
        location:     h[:location].to_s.strip
      }

      opp = Opportunity.find_or_initialize_by(finder)

      allowed = h.slice(
        :title,:description,:category,:organization,:location,
        :time_commitment,:latitude,:longitude,:tags,:image_url
      )
      allowed[:is_active] = (h[:is_active].to_s.downcase != "false")

      if opp.new_record?
        opp.assign_attributes(allowed)
        if dry
          created += 1
        else
          unless opp.save
            errors << { row: h, messages: opp.errors.full_messages }
          else
            created += 1
          end
        end
      else
        before = opp.attributes.dup
        opp.assign_attributes(allowed)
        if opp.changed?
          if dry
            updated += 1
          else
            unless opp.save
              errors << { row: h, messages: opp.errors.full_messages }
            else
              updated += 1
            end
          end
        else
          skipped_dup += 1
        end
      end
    end

    puts "✅ Import terminé"
    puts "   • créés:      #{created}"
    puts "   • mis à jour: #{updated}"
    puts "   • inchangés:  #{skipped_dup}"
    puts "   • erreurs:    #{errors.size}"
    if errors.any?
      puts "—— Détails erreurs ——"
      errors.first(10).each_with_index do |e, i|
        puts "[#{i+1}] #{e[:messages].join(', ')}"
        puts "     titre: #{e[:row][:title]} — org: #{e[:row][:organization]} — loc: #{e[:row][:location]}"
      end
      puts "  (…#{errors.size-10} de plus)" if errors.size > 10
    end
    puts dry ? "💡 DRY_RUN=1 (rien écrit en base)" : ""
  end
end
