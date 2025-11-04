# lib/tasks/declic_export.rake
# Exporte toutes les opportunités et toutes les belles histoires en CSV

namespace :declic do
  desc "Exporte toutes les opportunités et les histoires en CSV dans backups/"
  task export_all: :environment do
    require "csv"
    require "fileutils"

    dir = Rails.root.join("backups")
    FileUtils.mkdir_p(dir)

    ts = Time.now.strftime("%Y%m%d-%H%M%S")

    # ---------- Opportunities ----------
    opp_headers = %w[
      id title description category organization location time_commitment
      starts_at ends_at latitude longitude is_active tags image_url source_url
      created_at updated_at
    ]

    opp_path = dir.join("opportunities_all.csv") # (si tu préfères version horodatée: "#{ts}-opportunities_all.csv")
    CSV.open(opp_path, "w", force_quotes: true) do |csv|
      csv << opp_headers
      Opportunity.find_each(batch_size: 1000) do |o|
        row = opp_headers.map do |k|
          v = o.send(k) if o.respond_to?(k)
          v = v.iso8601 if v.respond_to?(:iso8601)
          v
        end
        csv << row
      end
    end

    # ---------- Stories ----------
    story_headers = %w[
      id slug title chapo description body location latitude longitude
      source_name source_url image_url created_at updated_at
    ]
    # Ajoute "quote" si la colonne existe dans ta base
    story_headers << "quote" if Story.column_names.include?("quote")

    stories_path = dir.join("stories_all.csv") # ou "#{ts}-stories_all.csv"
    CSV.open(stories_path, "w", force_quotes: true) do |csv|
      csv << story_headers
      Story.find_each(batch_size: 1000) do |s|
        row = story_headers.map do |k|
          v = s.send(k) if s.respond_to?(k)
          v = v.iso8601 if v.respond_to?(:iso8601)
          v
        end
        csv << row
      end
    end

    puts "✅ Export OK"
    puts "• Opportunities -> #{opp_path.relative_path_from(Rails.root)}"
    puts "• Stories       -> #{stories_path.relative_path_from(Rails.root)}"
  end
end
