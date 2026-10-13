# frozen_string_literal: true

module Veille
  module Connectors
    # Source 6 — flux RSS de la presse locale (hebdomadaire). Le flux n'est lu
    # que si son robots.txt l'autorise ; on ne visite AUCUN article : seuls
    # titre, chapeau, date et lien du flux sont gardés. Un article est retenu si
    # son titre ou chapeau cite une commune du Grand Nancy.
    #
    # Les requêtes d'alerte (« Nancy portrait », « Vandœuvre reconversion »,
    # « Grand Nancy association initiative ») se ramènent à un couple « commune du
    # Grand Nancy + un mot de SUJETS » dans le titre ou le chapeau.
    class Presse < Base
      FLUX = {
        "L'Est Républicain"     => "https://www.estrepublicain.fr/rss",
        "France 3 Grand Est"    => "https://france3-regions.francetvinfo.fr/grand-est/rss?r=grand-est"
      }.freeze

      SUJETS = %w[portrait reconversion association initiative benevole engagement solidaire solidarite
                  jardin partage reparation entrepreneur creatrice createur fondatrice fondateur].freeze

      def initialize(flux: FLUX, **opts)
        super(**opts)
        @flux = flux
      end

      def origin = "presse"

      def collect
        @flux.flat_map do |nom, url|
          Nokogiri::XML(http.get(url)).xpath("//item").filter_map { |n| item_pour(n, nom) }
        end
      end

      def item_pour(noeud, nom_flux)
        titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
        chapeau = Veille::Text.plain(noeud.at_xpath("description")&.text).slice(0, 600)
        lien = noeud.at_xpath("link")&.text.to_s.strip
        brut = "#{titre} #{chapeau}"
        commune = Veille::GrandNancy.trouver_dans(brut) or return nil
        return nil unless correspond_a_une_alerte?(brut)

        Item.new(origin: origin, url: lien, title: titre, text: "#{nom_flux}. #{chapeau}",
                 published_on: parse_date(noeud.at_xpath("pubDate")&.text), commune: commune,
                 type_hint: nil, reliability: "moyenne")
      end

      def correspond_a_une_alerte?(texte)
        norme = Veille::Text.normalize(texte)
        SUJETS.any? { |s| norme.include?(s) }
      end
    end
  end
end
