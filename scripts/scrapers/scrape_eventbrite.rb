# Scraper Eventbrite
# Usage: rails runner scripts/scrapers/scrape_eventbrite.rb

require 'nokogiri'
require 'httparty'
require 'json'

class EventbriteScraper
  CITIES = {
    'Nancy' => 'france--nancy',
    'Paris' => 'france--paris'
  }

  def self.scrape_all
    CITIES.each do |city_name, city_slug|
      scrape_city(city_name, city_slug)
    end
  end

  def self.scrape_city(city_name, city_slug)
    puts "\n🔍 Scraping Eventbrite #{city_name}..."
    
    url = "https://www.eventbrite.fr/d/#{city_slug}/events/"
    
    response = HTTParty.get(url, {
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept' => 'text/html,application/xhtml+xml'
      },
      follow_redirects: true
    })

    unless response.success?
      puts "❌ Erreur #{city_name}: #{response.code}"
      return
    end

    # Eventbrite charge souvent les événements en JSON dans le HTML
    # Cherche le JSON embarqué
    json_data = extract_json_data(response.body)
    
    if json_data
      import_from_json(json_data, city_name)
    else
      # Fallback: parse HTML classique
      import_from_html(response.body, city_name)
    end
  end

  def self.extract_json_data(html)
    # Eventbrite met souvent les données dans un <script type="application/ld+json">
    doc = Nokogiri::HTML(html)
    
    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        data = JSON.parse(script.content)
        return data if data['@type'] == 'ItemList' || data.is_a?(Array)
      rescue JSON::ParserError
        next
      end
    end
    
    nil
  end

  def self.import_from_json(data, city_name)
    imported = 0
    events = data.is_a?(Array) ? data : data['itemListElement'] || []
    
    events.each do |event_data|
      begin
        event = event_data['item'] || event_data
        
        title = event['name']
        next if title.blank?
        next if Opportunity.exists?(title: title, city: city_name)
        
        Opportunity.create!(
          title: title,
          description: event['description'] || "Événement à #{city_name}",
          category: detect_category(title),
          location: "#{city_name}, France",
          address: extract_location(event),
          city: city_name,
          starts_at: parse_date(event['startDate']),
          ends_at: parse_date(event['endDate']),
          external_url: event['url'],
          organization: event['organizer']&.dig('name') || 'Eventbrite',
          source: 'Eventbrite',
          latitude: get_lat(city_name),
          longitude: get_lng(city_name)
        )
        
        imported += 1
        print "."
      rescue => e
        # Continue silencieusement
      end
    end
    
    puts "\n✅ #{imported} opportunités importées depuis Eventbrite #{city_name}"
  end

  def self.import_from_html(html, city_name)
    doc = Nokogiri::HTML(html)
    imported = 0
    
    # Sélecteurs Eventbrite courants
    doc.css('div[data-event-id], article.event-card, .discover-search-desktop-card').each do |event|
      begin
        title = event.css('h2, h3, .event-card__title, [class*="title"]').first&.text&.strip
        next if title.blank?
        next if Opportunity.exists?(title: title, city: city_name)
        
        description = event.css('p, .event-card__description').first&.text&.strip || "Événement à #{city_name}"
        url = event.css('a').first&.[]('href')
        url = "https://www.eventbrite.fr#{url}" if url && !url.start_with?('http')
        
        Opportunity.create!(
          title: title,
          description: description,
          category: detect_category(title),
          location: "#{city_name}, France",
          city: city_name,
          external_url: url,
          organization: 'Eventbrite',
          source: 'Eventbrite',
          latitude: get_lat(city_name),
          longitude: get_lng(city_name)
        )
        
        imported += 1
        print "."
      rescue => e
        # Continue
      end
    end
    
    puts "\n✅ #{imported} opportunités importées depuis Eventbrite #{city_name}"
  end

  def self.extract_location(event)
    location = event.dig('location', 'address', 'streetAddress') ||
               event.dig('location', 'name')
    location
  end

  def self.parse_date(date_str)
    return nil if date_str.blank?
    begin
      Date.parse(date_str)
    rescue
      nil
    end
  end

  def self.detect_category(title)
    title_lower = title.downcase
    
    return 'ecologiser' if title_lower =~ /(écolo|environnement|nature|bio|durable|climat|zéro déchet)/
    return 'formation' if title_lower =~ /(atelier|formation|workshop|cours|masterclass|séminaire)/
    return 'rencontres' if title_lower =~ /(networking|meetup|café|apéro|concert|festival|expo)/
    return 'benevolat' if title_lower =~ /(solidaire|bénévol|don\b|aide|humanitaire)/
    return 'entreprendre' if title_lower =~ /(startup|entrepreneur|pitch|business|innovation)/
    
    'rencontres'
  end

  def self.get_lat(city)
    city == 'Nancy' ? 48.6921 : 48.8566
  end

  def self.get_lng(city)
    city == 'Nancy' ? 6.1844 : 2.3522
  end
end

# Exécution
EventbriteScraper.scrape_all
