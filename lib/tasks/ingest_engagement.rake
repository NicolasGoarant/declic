# frozen_string_literal: true
namespace :ingest do
  desc "Ingestion API Engagement (ex: rails 'ingest:engagement[Paris,Nancy]')"
  task :engagement, [:cities, :keywords, :lat, :lon, :distance] => :environment do |_, args|
    api_key = ENV["ENGAGEMENT_API_KEY"]
    abort "⚠️  ENGAGEMENT_API_KEY manquant (exporte la variable d'environnement)" if api_key.blank?

    api  = EngagementApi.new
    imp  = EngagementImporter.new(api: api)

    base_filters = {}
    base_filters[:keywords] = args[:keywords] if args[:keywords].present?
    base_filters[:type]     = "benevolat" # ou "volontariat-service-civique"
    if args[:lat] && args[:lon]
      base_filters[:lat] = args[:lat].to_f
      base_filters[:lon] = args[:lon].to_f
      base_filters[:distance] = (args[:distance] || "25km")
    end

    total = 0
    if args[:cities].present?
      args[:cities].split(",").map(&:strip).reject(&:blank?).each do |city|
        filters = base_filters.merge(city: city)
        puts "→ Import #{city}…"
        total += imp.import!(filters: filters, max_rows: 2000)
      end
    else
      puts "→ Import national…"
      total += imp.import!(filters: base_filters, max_rows: 2000)
    end

    puts "✅ Import terminé : #{total} missions."
  end
end
