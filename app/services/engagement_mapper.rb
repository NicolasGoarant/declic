class EngagementMapper
  def self.to_opportunity_attrs(m)
    # Adresse principale (si plusieurs, on prend la première)
    addr = Array(m["addresses"]).find { |a| a.present? } || {}
    loc  = addr["location"] || {}

    lat = (loc["lat"] || loc["latitude"]).to_f if loc
    lon = (loc["lon"] || loc["lng"] || loc["longitude"]).to_f if loc

    # Description : privilégie la version HTML nettoyée si dispo
    desc_html = m["descriptionHtml"].to_s
    description =
      if desc_html.present?
        begin
          ActionView::Base.full_sanitizer.sanitize(desc_html)
        rescue
          desc_html.gsub(/<\/?[^>]*>/, " ") # fallback ultra simple
        end
      else
        m["description"].to_s
      end

    # Catégorie : la plupart des missions = bénévolat
    cat = m["type"].to_s
    category =
      if cat.downcase.include?("bene")
        "benevolat"
      elsif cat.downcase.include?("volont")
        "benevolat" # tu pourras créer une catégorie dédiée plus tard
      else
        "benevolat"
      end

    {
      source:          "api_engagement",
      external_id:     m["_id"].to_s,
      source_url:      m["applicationUrl"].presence || m["url"].to_s,
      title:           m["title"].to_s,
      description:     description,
      category:        category,
      organization:    (m["organizationName"] || m.dig("organization", "name")).to_s,
      website:         (m["organizationUrl"] || m.dig("organization", "website")).to_s,

      address:         [addr["street"], addr["postalCode"], addr["city"]].compact.join(", "),
      city:            (addr["city"] || m["city"]).to_s,
      postcode:        (addr["postalCode"] || m["postalCode"]).to_s,

      latitude:        lat.presence,
      longitude:       lon.presence,

      time_commitment: m["schedule"].to_s,
      starts_at:       (Time.iso8601(m["startAt"]) rescue nil),
      ends_at:         (Time.iso8601(m["endAt"])   rescue nil),
      published_at:    (Time.iso8601(m["postedAt"]) rescue nil),
      expires_at:      (Time.iso8601(m["expiresAt"]) rescue nil),

      tags:            Array(m["tags"]).join(", "),
      is_active:       true,

      raw_payload:     m
    }
  end
end