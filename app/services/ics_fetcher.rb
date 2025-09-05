require 'faraday'
require 'icalendar'

class IcsFetcher
  def fetch(url)
    ics = Faraday.get(url).body
    cal = Icalendar::Calendar.parse(ics).first
    Array(cal&.events).map do |ev|
      {
        external_id: ev.uid || Digest::SHA1.hexdigest(ev.to_s),
        title:       ev.summary.to_s,
        description: ev.description.to_s,
        location:    ev.location.to_s,
        starts_at:   ev.dtstart&.to_time,
        ends_at:     ev.dtend&.to_time
      }
    end
  end
end
