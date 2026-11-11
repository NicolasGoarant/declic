# frozen_string_literal: true

module Veille
  module Connectors
    # Flux RSS de la presse locale dont les conditions d'utilisation ne s'opposent pas à la
    # fouille de textes (Veille::AnnuairePresse). Stocke seulement : titre, lien d'origine, date,
    # source et l'extrait fourni par le flux (400 caractères au plus), pour le tri. Les articles
    # ne sont jamais ouverts. Le type (belle histoire ou opportunité) est laissé à l'enrichissement ;
    # les fiches publiées sont réécrites, avec un lien « pour en savoir plus » vers l'article.
    # Les journaux dont les CGU s'opposent à la fouille (groupe EBRA, actu.fr) ne sont pas lus ici.
    class FluxPresse < Base
      DEPUIS_JOURS = 14
      EXTRAIT_MAX  = 400

      def initialize(sources: Veille::AnnuairePresse.automatisables, **opts)
        super(**opts)
        @sources = sources
        @erreurs = {}
      end

      def origin = "presse_rss"

      def collect
        flux = @sources.flat_map { |s| s.flux.map { |url| [s, url] } }
        items = flux.flat_map do |source, url|
          items_de(source, url)
        rescue Veille::Http::Error => e
          @erreurs[url] = e
          Rails.logger.warn("[Veille] FluxPresse #{source.nom} : #{e.message}")
          []
        end
        raise @erreurs.values.first if flux.any? && @erreurs.size == flux.size

        items.uniq(&:url)
      end

      def call
        resultat = super
        return resultat if @erreurs.empty? || resultat.statut != :ok

        resultat.message += " ; en échec : #{@erreurs.map { |u, e| "#{URI.parse(u).host} (#{e.message.slice(0, 80)})" }.join(', ')}"
        resultat
      end

      private

      def items_de(source, url)
        Nokogiri::XML(http.get(url)).xpath("//item").filter_map { |noeud| item_pour(noeud, source) }
      end

      def item_pour(noeud, source)
        titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
        lien  = noeud.at_xpath("link")&.text.to_s.strip
        return nil if titre.blank? || !source.lien_autorise?(lien)
        return nil if source.categorie_exclue?(noeud.xpath("category").map(&:text))

        publie = date_de(noeud.at_xpath("pubDate")&.text)
        return nil if publie && publie < today - DEPUIS_JOURS

        extrait = Veille::Text.plain(noeud.at_xpath("description")&.text).slice(0, EXTRAIT_MAX)
        texte = [titre, extrait.presence, "Source : #{source.nom}"].compact.join(". ")

        Item.new(origin: source.origine, url: lien.sub(/[?&]at_medium=.*\z/, ""), title: titre, text: texte,
                 published_on: publie, reliability: "moyenne")
      end

      def date_de(valeur)
        valeur.present? ? Time.zone.parse(valeur.to_s)&.to_date : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
