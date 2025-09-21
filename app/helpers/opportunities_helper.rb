# app/helpers/opportunities_helper.rb
module OpportunitiesHelper
  include ActionView::Helpers::SanitizeHelper

  # 1) URL externe prioritaire (normalisée https://…)
  def ext_url_for(op)
    candidates = %i[
      external_url url link_url website website_url
      registration_url signup_url source_url info_url more_info_url
    ]
    raw = candidates.lazy.map { |m| op.respond_to?(m) && op.public_send(m) }.find { |x| x.present? }
    normalize_http(raw)
  end

  def normalize_http(u)
    return nil if u.blank?
    s = u.to_s.strip
    s = "https://#{s}" if s =~ /\Awww\./i
    s if s =~ /\Ahttps?:\/\//i
  end

  # 2) Lien Google Calendar si starts_at(/ends_at)
  def gcal_url(op)
    return unless op.respond_to?(:starts_at) && op.starts_at.present?
    s = op.starts_at.utc.strftime('%Y%m%dT%H%M%SZ')
    e = (op.try(:ends_at) || op.starts_at + 1.hour).utc.strftime('%Y%m%dT%H%M%SZ')
    q = {
      action:  'TEMPLATE',
      text:    op.title,
      dates:   "#{s}/#{e}",
      details: strip_tags(op.description.to_s),
      location: op.location
    }.to_query
    "https://www.google.com/calendar/render?#{q}"
  end

  # 3) Lien Google Maps sur l’adresse
  def maps_url(op)
    return unless op.location.present?
    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(op.location.to_s)}"
  end
end
