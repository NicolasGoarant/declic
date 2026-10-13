# frozen_string_literal: true

module Veille
  module Connectors
    # Source 4 — offres de cession-reprise de Transentreprise. Le flux RSS public
    # (/rss/offre, non visé par robots.txt) liste les offres de la semaine ; on
    # garde celles de l'arrondissement de Nancy (le chemin de l'annonce contient
    # « meurthe-et-moselle » + « nancy »). On ne conserve que titre, accroche et
    # lien : la fiche Déclic est réécrite et renvoie vers l'annonce d'origine.
    class Transentreprise < Base
      FLUX = "https://www.transentreprise.com/rss/offre"

      def origin = "transentreprise"

      def collect
        Nokogiri::XML(http.get(FLUX)).xpath("//item").filter_map { |n| item_pour(n) }
      end

      def item_pour(noeud)
        lien = noeud.at_xpath("link")&.text.to_s.strip
        return nil unless lien.include?("/meurthe-et-moselle/") && lien.match?(/nancy/i)

        Item.new(
          origin: origin, url: lien, title: Veille::Text.plain(noeud.at_xpath("title")&.text),
          text: Veille::Text.plain(noeud.at_xpath("description")&.text).slice(0, 1500),
          published_on: parse_date(noeud.at_xpath("pubDate")&.text),
          schedule_text: "Annonce de cession, ouverte jusqu'à la reprise", commune: "Nancy",
          category_hint: "entreprendre", type_hint: "opportunite", reliability: "haute"
        )
      end
    end
  end
end
