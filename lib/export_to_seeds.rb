# lib/export_to_seeds.rb

require 'yaml'
require 'active_record'

# Démarre l'environnement Rails
# Nécessite un environnement Rails déjà initialisé (via rails runner)

puts "--- Début de l'exportation des Stories vers db/seeds.rb ---"

# 1. Récupère toutes les Stories actives
stories_to_export = Story.where(is_active: true).order(:id)

# 2. Formate chaque Story
stories_data_export = stories_to_export.map do |story|
  # Sélectionne uniquement les attributs pertinents pour les seeds
  attributes = story.attributes.slice(
    'title', 'chapo', 'body', 'location', 'happened_on',
    'source_name', 'image_url', 'latitude', 'longitude', 'is_active'
  )

  # Utilise le format HereDoc pour le corps (Markdown) pour la lisibilité
  attributes['body'] = "<<~MARKDOWN\n#{attributes['body']}\nMARKDOWN"

  # Retourne l'objet avec les clés en symboles, prêt à être inséré
  attributes.transform_keys!(&:to_sym)

  # Assure que la date est au bon format
  attributes[:happened_on] = "Date.new(#{story.happened_on.year}, #{story.happened_on.month}, #{story.happened_on.day})" if story.happened_on.present?

  attributes
end

# 3. Génère le fichier de sortie
output_file = File.join(Rails.root, 'db', 'exported_stories_data.rb')

File.open(output_file, 'w') do |file|
  file.puts "# Ce fichier a été généré automatiquement depuis la base de données locale (via lib/export_to_seeds.rb)"
  file.puts "# NE PAS MODIFIER DIRECTEMENT ! Copiez/Collez dans db/seeds.rb"
  file.puts "stories_data_GENERATED = ["

  stories_data_export.each do |data|
    # Génération du bloc Ruby pour la lisibilité
    file.puts "  {"
    data.each do |key, value|
      if key == :body
        file.puts "    #{key}: #{value}," # Le body est déjà formaté comme HereDoc
      elsif key == :happened_on && value.is_a?(String)
        file.puts "    #{key}: #{value}," # La date est formatée en Ruby
      else
        file.puts "    #{key}: #{value.inspect}," # Les autres sont inspectés (strings, floats)
      end
    end
    file.puts "  },"
  end

  file.puts "]"
end

puts "✅ Succès : #{stories_to_export.count} Stories exportées vers #{output_file}"
