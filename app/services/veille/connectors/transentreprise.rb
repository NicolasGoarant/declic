# frozen_string_literal: true

module Veille
  module Connectors
    # Source 4 — offres de cession-reprise de Transentreprise. Le flux RSS public
    # (/rss/offre, non visé par robots.txt) liste les offres de la semaine ; on
    # garde celles de Meurthe-et-Moselle (le chemin de l'annonce contient
    # « meurthe-et-moselle », puis l'arrondissement). On ne conserve que titre, accroche et
    # lien : la fiche Déclic est réécrite et renvoie vers l'annonce d'origine.
    class Transentreprise < Base
      FLUX = "https://www.transentreprise.com/rss/offre"

      def origin = "transentreprise"

      def collect
        Nokogiri::XML(http.get(FLUX)).xpath("//item").filter_map { |n| item_pour(n) }
      end

      def item_pour(noeud)
        lien = noeud.at_xpath("link")&.text.to_s.strip
        return nil unless lien.include?("/meurthe-et-moselle/")

        titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
        accroche = Veille::Text.plain(noeud.at_xpath("description")&.text).slice(0, 1500)
        Item.new(
          origin: origin, url: lien, title: titre, text: accroche,
          published_on: parse_date(noeud.at_xpath("pubDate")&.text),
          schedule_text: "Annonce de cession, ouverte jusqu'à la reprise", commune: commune_de(lien, "#{titre} #{accroche}"),
          category_hint: "entreprendre", type_hint: "opportunite", reliability: "haute"
        )
      end

      private

      # La commune citée par l'annonce, sinon le chef-lieu de l'arrondissement du lien
      # (« .../meurthe-et-moselle/arr-de-toul », « .../nancy-et-arrondissement »).
      def commune_de(lien, texte)
        arrondissement = lien[%r{/meurthe-et-moselle/([^/?]+)}, 1].to_s.sub(/\Aarr-de-/, "").sub(/-et-arrondissement\z/, "")
        Veille::Territoire.trouver_dans(texte) || Veille::Territoire.canonique(arrondissement)
      end
    end
  end
end
