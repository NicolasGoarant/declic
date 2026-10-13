# frozen_string_literal: true

module Veille
  module Connectors
    # Source 1 — missions de bénévolat de l'API Engagement (JeVeuxAider et
    # partenaires), dans un rayon de 15 km autour de Nancy. Appel d'une API
    # officielle avec clé (ENGAGEMENT_API_KEY), pas d'une page web : pas de
    # robots.txt applicable. Sans date, la mission est « ouverte toute l'année ».
    class Engagement < Base
      NANCY    = { lat: 48.6921, lon: 6.1844 }.freeze
      DISTANCE = "15km"
      MAX      = 200
      REGIME   = "Ouvert toute l'année"

      def initialize(api: nil, **opts)
        super(**opts)
        @api = api
      end

      def origin = "jeveuxaider"

      def collect
        missions = api.get("/mission", NANCY.merge(distance: DISTANCE, type: "benevolat", limit: MAX, skip: 0))
        Array(missions["data"]).filter_map { |m| item_pour(m) }
      rescue EngagementApi::Error => e
        raise e.message.include?("manquant") ? NonConfigure.new(e.message) : e
      end

      def item_pour(m)
        fin = parse_date(m["endAt"])
        return nil if fin && fin < today

        debut = parse_date(m["startAt"])
        adresse = Array(m["addresses"]).find(&:present?) || {}
        ville = adresse["city"] || m["city"]
        description = Veille::Text.plain(m["descriptionHtml"].presence || m["description"])

        Item.new(
          origin: origin, url: m["applicationUrl"].presence || m["url"],
          title: m["title"], text: [m["organizationName"], description].compact_blank.join(" — "),
          published_on: parse_date(m["postedAt"]), starts_on: debut, ends_on: fin,
          schedule_text: (debut || fin ? nil : REGIME), commune: ville,
          category_hint: "benevolat", type_hint: "opportunite", reliability: "haute"
        )
      end

      private

      def api = @api ||= EngagementApi.new
    end
  end
end
