# frozen_string_literal: true

module Veille
  module Connectors
    # Veille presse MANUELLE : liste le titre et le lien des articles du flux RSS,
    # lus à l'ouverture de /admin/veille/presse. Volontairement hors du Runner et
    # sans #call ni Veille::Item : les CGU de L'Est Républicain s'opposent à la
    # fouille de textes. Rien n'est stocké, rien n'est envoyé à l'IA, et le chapeau
    # (<description>) n'est jamais lu. Un article n'entre en base que par le geste
    # « Retenir » de l'admin (Admin::Veille::PresseController).
    class Presse
      FLUX = {
        "L'Est Républicain" => "https://www.estrepublicain.fr/rss",
        "L'Est Républicain, édition de Nancy" => "https://www.estrepublicain.fr/edition-nancy-et-agglomeration/rss",
        "L'Est Républicain, rubrique Société" => "https://www.estrepublicain.fr/societe/rss"
      }.freeze

      Lien    = Struct.new(:titre, :url, :flux, :publie_le, keyword_init: true)
      Lecture = Struct.new(:liens, :erreurs, keyword_init: true)

      # Seuls les articles des journaux listés peuvent être retenus.
      def self.lien_autorise?(url)
        uri = URI.parse(url.to_s)
        uri.is_a?(URI::HTTP) && FLUX.values.any? { |f| URI.parse(f).host == uri.host }
      rescue URI::InvalidURIError
        false
      end

      def initialize(flux: FLUX, http: Veille::Http.new)
        @flux = flux
        @http = http
      end

      # Chaque flux est jugé à part : l'échec de l'un n'empêche pas de lire les autres.
      def lister
        erreurs = {}
        liens = @flux.flat_map do |nom, url|
          liens_de(nom, url)
        rescue Veille::Http::Error => e
          erreurs[nom] = e.message
          []
        end
        tries = liens.uniq(&:url).sort_by { |l| l.publie_le || Time.at(0) }.reverse
        Lecture.new(liens: tries, erreurs: erreurs)
      end

      private

      def liens_de(nom, url)
        Nokogiri::XML(@http.get(url)).xpath("//item").filter_map do |noeud|
          titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
          lien  = noeud.at_xpath("link")&.text.to_s.strip
          next if titre.blank? || !http?(lien)

          Lien.new(titre: titre, url: lien, flux: nom, publie_le: date(noeud.at_xpath("pubDate")&.text))
        end
      end

      def http?(url)
        URI.parse(url).is_a?(URI::HTTP)
      rescue URI::InvalidURIError
        false
      end

      def date(valeur)
        valeur.present? ? Time.zone.parse(valeur) : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
