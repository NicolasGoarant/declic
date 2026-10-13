# frozen_string_literal: true

module Veille
  module Connectors
    # Source 5 — La Gazette France, rubrique Meurthe-et-Moselle (robots.txt :
    # tout permis sauf pages paginées et recherche). On lit la page de rubrique,
    # puis chaque article (titre et chapeau en métadonnées, pas de texte intégral
    # conservé) ; on garde ceux qui citent une commune du Grand Nancy.
    class GazetteFrance < Base
      RUBRIQUE = "https://www.lagazettefrance.fr/meurthe-et-moselle"
      MAX      = 30

      def origin = "gazette"

      def collect
        doc = Nokogiri::HTML(http.get(RUBRIQUE))
        liens = doc.css("a[href^='/article/']").map { |a| URI.join(RUBRIQUE, a["href"]).to_s }.uniq.first(MAX)
        liens.filter_map { |u| item_pour(u) }
      end

      def item_pour(url)
        page = Veille::PageFetcher.extract(http.get(url), url: url)
        commune = Veille::GrandNancy.trouver_dans("#{page[:title]} #{page[:excerpt]}")
        return nil unless commune

        Item.new(origin: origin, url: url, title: page[:title], text: page[:excerpt].to_s,
                 published_on: page[:published_on], commune: commune,
                 reliability: "moyenne") # type et catégorie : à l'IA (événement éco, formation… ou simple info)
      rescue Veille::Http::Refused => e
        raise e
      rescue Veille::Http::Error
        nil
      end
    end
  end
end
