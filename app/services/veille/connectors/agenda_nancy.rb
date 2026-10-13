# frozen_string_literal: true

module Veille
  module Connectors
    # Source 2 — agenda mutualisé du Grand Nancy (celui de www.nancy.fr/agenda).
    # La page charge ses événements en JSON depuis agenda-integration.grandnancy.eu,
    # dont le robots.txt ne s'oppose à rien ; on lit ce JSON. Seules les rubriques
    # qui peuvent mener à agir ou rencontrer (conférences, citoyenneté, animations,
    # festivals) sont gardées : spectacles, concerts et expositions ne sont pas
    # des opportunités Déclic.
    class AgendaNancy < Base
      API    = "https://agenda-integration.grandnancy.eu/api/%s/events"
      DETAIL = "https://www.nancy.fr/agenda/details-agenda?uuid=%s"
      ENTITES = %w[vdn].freeze

      CATEGORIES = {
        "Conférence - Rencontre"   => "rencontres",
        "Citoyenneté"              => "benevolat",
        "Manifestation - Festival" => "rencontres",
        "Activité - Animation"     => "rencontres"
      }.freeze

      def origin = "agenda_nancy"

      def collect
        ENTITES.flat_map { |e| json(format(API, e)).filter_map { |ev| item_pour(ev) } }
      end

      def item_pour(ev)
        rubrique = ev.dig("mainCategory", "name")
        categorie = CATEGORIES[rubrique] or return nil
        fin = parse_date(ev["endDate"]) || parse_date(ev["startDate"])
        return nil if fin && fin < today

        ville = ev.dig("place", "city", "name")
        return nil if ville.present? && !Veille::GrandNancy.inclut?(ville)

        lieu = ev.dig("place", "name")
        texte = [ev["name"], rubrique, Array(ev["subCategories"]).map { |s| s["name"] }.join(", "),
                 lieu && "Lieu : #{lieu}", ville && "Commune : #{ville}", ev["duringDateText"].presence || ev["beforeDateText"],
                 ev["free"] ? "Gratuit" : nil, ev["reservation"] ? "Sur réservation" : nil]
                .compact_blank.join(". ")

        Item.new(
          origin: origin, url: format(DETAIL, ev["uuid"]), title: Veille::Text.plain(ev["name"]),
          text: Veille::Text.plain(texte), published_on: parse_date(ev["publicationDate"]),
          starts_on: parse_date(ev["startDate"]), ends_on: parse_date(ev["endDate"]),
          commune: ville, category_hint: categorie, type_hint: "opportunite", reliability: "haute"
        )
      end
    end
  end
end
