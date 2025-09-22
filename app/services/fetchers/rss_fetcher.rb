# frozen_string_literal: true
require "feedjira"
require "open-uri"

module Fetchers
  class RssFetcher
    def self.call(source)
      xml  = URI.open(source.url, read_timeout: 20).read
      feed = Feedjira.parse(xml)
      return [] unless feed&.entries

      feed.entries.map do |it|
        {
          title: it.title&.to_s&.strip,
          summary: ActionView::Base.full_sanitizer.sanitize((it.summary || it.content || "").to_s).strip[0,240],
          url: it.url,
          organizer_name: source.name,
          source: "RSS: #{source.name}",
          starts_at: it.published || Time.zone.now,
          timezone: "Europe/Paris",
          category: "entreprendre",
          mode: "presentiel",
          intensity: "decouverte"
        }
      end
    rescue => _
      []
    end
  end
end
