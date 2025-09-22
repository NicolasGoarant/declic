# frozen_string_literal: true
require "open-uri"
require "nokogiri"
require "json"
require "uri"

module Fetchers
  class DeepJsonldFetcher
    # Parcourt la page liste (source.url), récupère des liens internes,
    # visite chaque page et extrait les Event JSON-LD des pages détail.
    MAX_LINKS = 30

    def self.call(source)
      base = URI.parse(source.url)
      html = URI.open(source.url, "User-Agent" => "DeclicBot/1.0", read_timeout: 20).read
      doc  = Nokogiri::HTML(html)

      links = doc.css('a[href]').map { |a| a["href"].to_s }.uniq
      links = links.filter_map do |href|
        begin
          u = URI.join(base, href)
          next nil unless %w[http https].include?(u.scheme)
          next nil unless u.host == base.host
          u.fragment = nil
          u.to_s
        rescue
          nil
        end
      end.uniq.first(MAX_LINKS)

      items = []
      links.each do |url|
        begin
          page = URI.open(url, "User-Agent" => "DeclicBot/1.0", read_timeout: 20).read
          d    = Nokogiri::HTML(page)
          scripts = d.css('script[type="application/ld+json"]').map(&:text)
          data = scripts.flat_map { |raw| JSON.parse(raw) rescue [] }
          nodes = data.flat_map { |h| h.is_a?(Hash) && h["@graph"].is_a?(Array) ? h["@graph"] : [h] }
          events = nodes.select { |n| n.is_a?(Hash) && n["@type"].to_s.downcase.include?("event") }

          events.each do |ev|
            title = ev["name"]&.to_s&.strip
            next if title.nil? || title.empty?
            start_date = ev["startDate"] || ev["start_time"]
            end_date   = ev["endDate"]   || ev["end_time"]
            addr = ev.dig("location", "address")
            items << {
              title: title,
              summary: ActionView::Base.full_sanitizer.sanitize(ev["description"].to_s).strip[0,300],
              starts_at: (Time.zone.parse(start_date) rescue nil),
              ends_at:   (Time.zone.parse(end_date)   rescue nil),
              venue_name: ev.dig("location", "name"),
              address: [addr&.[]("streetAddress"), addr&.[]("postalCode"), addr&.[]("addressLocality")].compact.join(", ").presence,
              city: addr&.[]("addressLocality"),
              url: ev["url"] || url,
              organizer_name: ev.dig("organizer", "name") || source.name,
              source: "DEEP-JSON-LD: #{source.name}",
              timezone: "Europe/Paris",
              category: "entreprendre",
              mode: "presentiel",
              intensity: "decouverte"
            }.compact
          end
        rescue
          next
        end
      end

      items
    rescue
      []
    end
  end
end
