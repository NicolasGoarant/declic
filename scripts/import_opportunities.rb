# Script d'import CSV pour Déclic
# Usage: rails runner scripts/import_opportunities.rb

require 'csv'

class OpportunityImporter
  CATEGORY_MAPPING = {
    'ecologiser' => 'ecologiser',
    'écologie' => 'ecologiser',
    'environnement' => 'ecologiser',
    'benevolat' => 'benevolat',
    'bénévolat' => 'benevolat',
    'solidaire' => 'benevolat',
    'formation' => 'formation',
    'cours' => 'formation',
    'atelier' => 'formation',
    'rencontres' => 'rencontres',
    'rencontre' => 'rencontres',
    'networking' => 'rencontres',
    'entreprendre' => 'entreprendre',
    'entrepreneuriat' => 'entreprendre',
    'startup' => 'entreprendre'
  }

  def self.import(csv_path)
    unless File.exist?(csv_path)
      puts "❌ Fichier #{csv_path} introuvable"
      return
    end

    imported = 0
    skipped = 0
    errors = 0

    CSV.foreach(csv_path, headers: true, col_sep: ',', encoding: 'UTF-8') do |row|
      begin
        # Normalise la catégorie
        category = normalize_category(row['category'])
        
        # Vérifie les doublons par titre + ville
        if Opportunity.exists?(title: row['title'], city: row['city'])
          skipped += 1
          next
        end

        # Crée l'opportunité
        Opportunity.create!(
          title: row['title']&.strip,
          description: row['description']&.strip,
          category: category,
          location: row['location']&.strip,
          address: row['address']&.strip,
          city: row['city']&.strip || extract_city(row['location']),
          starts_at: parse_date(row['starts_at']),
          ends_at: parse_date(row['ends_at']),
          external_url: row['external_url']&.strip,
          organization: row['organization']&.strip,
          source: row['source'] || 'CSV Import',
          latitude: row['latitude']&.to_f,
          longitude: row['longitude']&.to_f
        )

        imported += 1
        print "."
      rescue => e
        errors += 1
        puts "\n⚠️  Erreur ligne #{$.}: #{e.message}"
      end
    end

    puts "\n\n✅ Import terminé !"
    puts "━" * 50
    puts "📊 Résultats :"
    puts "  ✅ Importées : #{imported}"
    puts "  ⏭️  Ignorées (doublons) : #{skipped}"
    puts "  ❌ Erreurs : #{errors}"
    puts "━" * 50
    puts "📈 Total opportunités : #{Opportunity.count}"
  end

  def self.normalize_category(cat)
    return 'rencontres' if cat.blank?
    
    cat_lower = cat.to_s.downcase.strip
    CATEGORY_MAPPING[cat_lower] || cat_lower
  end

  def self.parse_date(date_str)
    return nil if date_str.blank?
    
    # Gère différents formats
    begin
      Date.parse(date_str)
    rescue
      nil
    end
  end

  def self.extract_city(location)
    return 'Nancy' if location.blank?
    
    # Extrait la ville depuis "Nancy, France" ou "12 rue X, Nancy"
    parts = location.split(',')
    city = parts[-2] || parts[-1]
    city&.strip
  end
end

# Exécution
csv_file = ARGV[0] || 'data/opportunities.csv'
OpportunityImporter.import(csv_file)
