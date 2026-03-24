# Scraper Nancy.fr Agenda
# Usage: rails runner scripts/scrapers/scrape_nancy.rb

require 'nokogiri'
require 'httparty'
require 'date'

class NancyScraper
  BASE_URL = "https://www.nancy.fr"
  AGENDA_URL = "#{BASE_URL}/agenda"

  def self.scrape
    puts "🔍 Scraping Nancy.fr agenda..."
    
    response = HTTParty.get(AGENDA_URL, {
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    })

    unless response.success?
      puts "❌ Erreur: #{response.code}"
      return
    end

    doc = Nokogiri::HTML(response.body)
    imported = 0
    
    # Sélecteur CSS pour les événements (à adapter selon la structure réelle)
    doc.css('.event-item, .agenda-item, article.event').each do |event|
      begin
        title = extract_title(event)
        next if title.blank?
        
        # Évite les doublons
        next if Opportunity.exists?(title: title, city: 'Nancy')
        
        Opportunity.create!(
          title: title,
          description: extract_description(event),
          category: detect_category(title),
          location: "Nancy, France",
          address: extract_address(event),
          city: 'Nancy',
          starts_at: extract_date(event),
          external_url: extract_url(event),
          organization: "Ville de Nancy",
          source: 'nancy.fr',
          latitude: 48.6921,
          longitude: 6.1844
        )
        
        imported += 1
        print "."
      rescue => e
        puts "\n⚠️  Erreur: #{e.message}"
      end
    end
    
    puts "\n✅ #{imported} opportunités importées depuis nancy.fr"
  end

  private

  def self.extract_title(event)
    # Essaie plusieurs sélecteurs courants
    title = event.css('h2, h3, .title, .event-title').first&.text&.strip ||
            event.css('a').first&.text&.strip
    title
  end

  def self.extract_description(event)
    desc = event.css('.description, .content, .excerpt, p').first&.text&.strip
    desc.presence || "Événement organisé par la Ville de Nancy"
  end

  def self.extract_address(event)
    addr = event.css('.location, .address, .lieu').first&.text&.strip
    addr.presence || "Nancy, France"
  end

  def self.extract_date(event)
    date_text = event.css('.date, time, .event-date').first&.text&.strip
    return nil if date_text.blank?
    
    # Parse les formats français courants
    begin
      # Format: "20 mars 2026" ou "20/03/2026"
      if date_text =~ /(\d{1,2})\s*(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)\s*(\d{4})/i
        day = $1.to_i
        month = french_month_to_number($2)
        year = $3.to_i
        Date.new(year, month, day)
      elsif date_text =~ /(\d{1,2})\/(\d{1,2})\/(\d{4})/
        Date.parse(date_text)
      else
        nil
      end
    rescue
      nil
    end
  end

  def self.extract_url(event)
    link = event.css('a').first&.[]('href')
    return nil if link.blank?
    
    link.start_with?('http') ? link : "#{BASE_URL}#{link}"
  end

  def self.french_month_to_number(month)
    months = {
      'janvier' => 1, 'février' => 2, 'mars' => 3, 'avril' => 4,
      'mai' => 5, 'juin' => 6, 'juillet' => 7, 'août' => 8,
      'septembre' => 9, 'octobre' => 10, 'novembre' => 11, 'décembre' => 12
    }
    months[month.downcase] || 1
  end

  def self.detect_category(title)
    title_lower = title.downcase
    
    return 'ecologiser' if title_lower =~ /(écolo|environnement|nature|jardin|vélo|bio)/
    return 'formation' if title_lower =~ /(atelier|formation|cours|stage)/
    return 'rencontres' if title_lower =~ /(concert|exposition|spectacle|festival|café|rencontre)/
    return 'benevolat' if title_lower =~ /(solidaire|bénévol|aide)/
    return 'entreprendre' if title_lower =~ /(entrepreneur|startup|innovation)/
    
    'rencontres'
  end
end

# Exécution
NancyScraper.scrape
