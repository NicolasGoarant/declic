# frozen_string_literal: true
require "open-uri"
require "nokogiri"
require "uri"
require_relative "../support/french_date_parser"

module Fetchers
  class CciNancyFetcher
    include Support::FrenchDateParser
    MAX_LINKS = 25

    def self.call(source)
      new.call(source)
    end

    def call(source)
      base = URI.parse(source.url)
      html = URI.open(source.url, "User-Agent" => "DeclicBot/1.0", read_timeout: 20).read
      doc  = Nokogiri::HTML(html)

      # liens internes vers des fiches "événement" ou "formation"
      links = doc.css('a[href]').map { |a| a["href"].to_s }.uniq
      links = links.filter_map do |href|
        u = safe_join(base, href)
        next nil unless u
        next nil unless u.host == base.host
        next nil unless u.to_s.match?(/evenement|formation|agenda|event/i)
        u.to_s
      end.uniq.first(MAX_LINKS)

      items = []
      links.each do |url|
        begin
          page = URI.open(url, "User-Agent" => "DeclicBot/1.0", read_timeout: 20).read
          d    = Nokogiri::HTML(page)

          title = d.at_css("h1")&.text&.strip
          title = d.at_css("meta[property='og:title']")&.[]("content")&.strip if title.blank?
          next if title.blank?

          body_text = d.at_css("main")&.text || d.text
          # Heuristiques date/lieu :
          starts_at = Support::FrenchDateParser.parse_french_datetime(body_text)
          venue = d.at_css("[class*='lieu'], [class*='adresse'], .location, .place")&.text&.strip
          venue = nil if venue&.length.to_i < 4

          items << {
            title: title,
            summary: (d.at_css("meta[name='description']")&.[]("content") || "").strip[0,300],
            starts_at: starts_at,
            venue_name: venue,
            city: venue&.split&.last, # approximation
            url: url,
            organizer_name: "CCI Grand Nancy",
            source: "CCI-Nancy (scrape)",
            timezone: "Europe/Paris",
            category: "entreprendre",
            mode: "presentiel",
            intensity: "decouverte"
          }.compact
        rescue
          next
        end
      end
      items
    rescue
      []
    end

    private

    def safe_join(base, href)
      u = URI.join(base, href) rescue nil
      return nil unless u && %w[http https].include?(u.scheme)
      u.fragment = nil
      u
    end
  end
end
