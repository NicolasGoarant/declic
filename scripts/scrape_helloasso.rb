# Script pour scraper HelloAsso
# Usage: rails runner scripts/scrape_helloasso.rb

require 'httparty'
require 'json'

class HelloAssoScraper
  BASE_URL = "https://api.helloasso.com/v5"
  
  def self.scrape_events(city: "Nancy", limit: 100)
    # HelloAsso Public API
    url = "#{BASE_URL}/organizations/search"
    
    response = HTTParty.get(url, {
      query: {
        city: city,
        pageSize: limit,
        pageIndex: 1
      }
    })
    
    return unless response.success?
    
    data = JSON.parse(response.body)
    count = 0
    
    data['data']&.each do |org|
      # Pour chaque organisation, récupère ses événements
      events = fetch_org_events(org['organizationSlug'])
      
      events&.each do |event|
        create_opportunity(event, org)
        count += 1
      end
    end
    
    puts "✅ #{count} opportunités importées depuis HelloAsso"
  end
  
  def self.fetch_org_events(org_slug)
    url = "#{BASE_URL}/organizations/#{org_slug}/forms"
    response = HTTParty.get(url, query: { formType: 'Event' })
    
    return [] unless response.success?
    JSON.parse(response.body)['data'] || []
  end
  
  def self.create_opportunity(event, org)
    # Évite les doublons
    return if Opportunity.exists?(external_id: event['formSlug'])
    
    Opportunity.create!(
      title: event['title'],
      description: event['description'] || "Événement organisé par #{org['name']}",
      category: detect_category(event['title']),
      location: "#{event['place']&.dig('city') || 'Nancy'}, France",
      address: event['place']&.dig('address'),
      latitude: event['place']&.dig('latitude'),
      longitude: event['place']&.dig('longitude'),
      starts_at: event['startDate'],
      ends_at: event['endDate'],
      external_url: "https://www.helloasso.com/associations/#{org['organizationSlug']}/evenements/#{event['formSlug']}",
      organization: org['name'],
      external_id: event['formSlug'],
      source: 'HelloAsso'
    )
  rescue => e
    puts "⚠️  Erreur : #{e.message}"
  end
  
  def self.detect_category(title)
    title_lower = title.downcase
    
    return 'ecologiser' if title_lower =~ /(écolo|environnement|nature|bio|climat)/
    return 'formation' if title_lower =~ /(formation|atelier|cours|apprentissage)/
    return 'rencontres' if title_lower =~ /(rencontre|café|apéro|networking|meetup)/
    return 'benevolat' if title_lower =~ /(bénévol|solidaire|aide|don\b)/
    return 'entreprendre' if title_lower =~ /(entrepreneur|startup|pitch|business)/
    
    'rencontres' # Défaut
  end
end

# Exécution
HelloAssoScraper.scrape_events(city: "Nancy", limit: 50)
HelloAssoScraper.scrape_events(city: "Paris", limit: 50)
