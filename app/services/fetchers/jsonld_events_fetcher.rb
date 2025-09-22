# frozen_string_literal: true
require "open-uri"
require "json"
require "nokogiri"

module Fetchers
  class JsonldEventsFetcher
    def self.call(source)
      html = URI.open(source.url, "User-Agent" => "DeclicBot/1.0", read_timeout: 20).read
      doc  = Nokogiri::HTML(html)
      scripts = doc.css('script[type="application/ld+json"]').map(&:text)

      data = scripts.flat_map { |raw| JSON.parse(raw) rescue [] }
      nodes = data.flat_map { |h| h.is_a?(Hash) && h["@graph"].is_a?(Array) ? h["@graph"] : [h] }
      events = nodes.select { |n| n.is_a?(Hash) && n["@type"].to_s.downcase.include?("event") }

      events.filter_map do |ev|
        title = ev["name"]&.to_s&.strip
        next if title.nil? || title.empty?
        start_date = ev["startDate"] || ev["start_time"]
        end_date   = ev["endDate"]   || ev["end_time"]
        addr = ev.dig("location", "address")

        {
          title: title,
          summary: ActionView::Base.full_sanitizer.sanitize(ev["description"].to_s).to_s.strip[0,300],
          starts_at: (Time.zone.parse(start_date) rescue nil),
          ends_at:   (Time.zone.parse(end_date)   rescue nil),
          venue_name: ev.dig("location", "name"),
          address: [addr&.[]("streetAddress"), addr&.[]("postalCode"), addr&.[]("addressLocality")].compact.join(", ").presence,
          city: addr&.[]("addressLocality"),
          url: ev["url"] || source.url,
          organizer_name: ev.dig("organizer", "name") || source.name,
          source: "JSON-LD: #{source.name}",
          timezone: "Europe/Paris",
          category: "entreprendre",
          mode: "presentiel",
          intensity: "decouverte"
        }.compact
      end
    rescue => _
      []
    end
  end
end
