# frozen_string_literal: true
require "icalendar"
require "open-uri"

module Fetchers
  class IcsFetcher
    def self.call(source)
      ics = URI.open(source.url, read_timeout: 20).read
      cal = Icalendar::Calendar.parse(ics).first
      return [] unless cal

      cal.events.filter_map do |e|
        next unless e&.dtstart
        {
          title: e.summary.to_s.strip.presence,
          starts_at: e.dtstart.to_time,
          ends_at: e.dtend&.to_time,
          venue_name: e.location.to_s.strip.presence,
          url: (e.url || source.url).to_s,
          organizer_name: source.name,
          source: "ICS: #{source.name}",
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
