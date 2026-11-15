# frozen_string_literal: true

module Veille
  module Connectors
    # Source 2 — agenda mutualisé du Grand Nancy (celui de www.nancy.fr/agenda).
    # La page charge ses événements en JSON depuis agenda-integration.grandnancy.eu,
    # dont le robots.txt ne s'oppose à rien ; on lit ce JSON. Seules les rubriques
    # qui peuvent mener à agir, pratiquer ou découvrir (conférences, citoyenneté, animations,
    # festivals) sont gardées : spectacles, concerts et expositions ne sont pas
    # des opportunités Déclic.
    class AgendaNancy < Base
      API    = "https://agenda-integration.grandnancy.eu/api/%s/events"
      DETAIL = "https://www.nancy.fr/agenda/details-agenda?uuid=%s"
      ENTITES = %w[vdn].freeze

      CATEGORIES = {
        "Conférence - Rencontre"   => "decouvrir",
        "Citoyenneté"              => "benevolat",
        "Manifestation - Festival" => "decouvrir",
        "Activité - Animation"     => "pratiquer"
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
        return nil if ville.present? && !Veille::Territoire.meurthe_et_moselle?(ville)

        lieu = ev.dig("place", "name")
        sous_rubriques = Array(ev["subCategories"]).map { |s| s["name"] }.reject { |n| n == rubrique }
        texte = [ev["name"], rubrique, sous_rubriques.join(", "),
                 lieu && "Lieu : #{lieu}", ville && "Commune : #{ville}", texte_de_date(ev),
                 ev["free"] ? "Gratuit" : nil, ev["reservation"] ? "Sur réservation" : nil]
                .compact_blank.join(". ")

        # L'agenda donne début et fin ; son texte de date (« Jusqu'au 28 mars, tous les samedis de 11h à 12h »)
        # apporte les heures et la périodicité, et sert de repli aux dates absentes.
        quand = Veille::DatesFrancais.analyser([ ev["duringDateText"], ev["beforeDateText"] ].compact_blank.join(". "), reference: today)
        Item.new(
          origin: origin, url: format(DETAIL, ev["uuid"]), title: Veille::Text.plain(ev["name"]),
          text: Veille::Text.plain(texte), published_on: parse_date(ev["publicationDate"]),
          starts_on: parse_date(ev["startDate"]) || quand.starts_on, ends_on: parse_date(ev["endDate"]) || quand.ends_on,
          start_time: quand.start_time, end_time: quand.end_time, schedule_text: quand.periodicite, commune: ville, category_hint: categorie, type_hint: "opportunite", reliability: "haute"
        )
      end

      RELATIF = /\A\s*(?:aujourd['’]hui|demain|hier|ce\s+soir|cette\s+semaine|ce\s+week-end)/i

      private

      # `duringDateText` est écrit pour le jour même (« Aujourd'hui à 15h » : 196 événements sur 348) : on n'en
      # garde que l'horaire. Pour un événement à plusieurs dates (dateList, ou début ≠ fin), la liste des
      # occurrences n'existe que dans `beforeDateText` (« Mercredis 9 décembre, 13 janvier… ») : on la garde, suivie
      # de l'horaire. Pour un seul jour, Veille::TextesRelatifs (appelé par Item) pose la date absolue.
      def texte_de_date(ev)
        pendant, avant = ev["duringDateText"].presence, ev["beforeDateText"].presence
        return pendant || avant unless pendant&.match?(RELATIF)

        plusieurs = Array(ev["dateList"]).size > 1 || (ev["endDate"].present? && ev["endDate"].to_s[0, 10] != ev["startDate"].to_s[0, 10])
        return pendant unless plusieurs && avant

        horaire = Veille::TextesRelatifs.nettoyer(pendant)
        horaire.present? && !avant.match?(/\d\s?h/) ? "#{avant} #{horaire}" : avant
      end
    end
  end
end
