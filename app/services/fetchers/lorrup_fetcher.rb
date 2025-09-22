# frozen_string_literal: true
require "open-uri"
require "nokogiri"
require "uri"
require_relative "../support/french_date_parser"

module Fetchers
  class LorrupFetcher
    include Support::FrenchDateParser
    MAX_LINKS = 60

    def self.call(source) = new.call(source)

    def call(source)
      base = URI.parse(source.url)
      list_html = URI.open(source.url, "User-Agent" => "DeclicBot/1.0", "Accept-Language" => "fr-FR,fr;q=0.9", read_timeout: 20).read
      list_doc  = Nokogiri::HTML(list_html)

      scope = list_doc.at_css("main") || list_doc
      raw_links = scope.css("a[href]").map { |a| a["href"].to_s }.uniq

      links = raw_links.filter_map { |href| safe_join(base, href)&.to_s }
                       .reject { |u| u =~ /\/evenements\/?$/i }                  # ❌ page catégorie
                       .select { |u| u.include?(base.host) }
                       .uniq
                       .first(MAX_LINKS)

      items = []
      links.each do |url|
        begin
          page = URI.open(url, "User-Agent" => "DeclicBot/1.0", "Accept-Language" => "fr-FR,fr;q=0.9", read_timeout: 20).read
          d    = Nokogiri::HTML(page)

          title = d.at_css("h1")&.text&.strip.presence ||
                  d.at_css("meta[property='og:title']")&.[]("content")&.strip
          next if title.blank? || title.match?(/\bCat[ée]gorie\b/i)               # ❌ pas une fiche

          body = d.at_css("article") || d.at_css("main") || d
          body_text = body.text

          # Heuristique d’intérêt
          interesting = (title =~ /atelier|webinaire|r[ée]union|afterwork|rencontre|matinale|porte ouverte|visite|conf[ée]rence|formation/i) ||
                        (body_text =~ /inscription|s'inscrire|participer/i)
          next unless interesting

          # Date FR (si présente)
          starts_at = Support::FrenchDateParser.parse_french_datetime(body_text)

          venue = d.at_css("[class*='lieu'], [class*='adresse'], .location, .place, .event-location")&.text&.strip
          venue = nil if venue&.length.to_i < 4

          items << {
            title: title,
            summary: (d.at_css("meta[name='description']")&.[]("content") || "").strip[0,300],
            starts_at: starts_at,
            venue_name: venue,
            city: venue&.split&.last,
            url: url,
            organizer_name: "Lorr’Up",
            source: "LorrUp (scrape)",
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
