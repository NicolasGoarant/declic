# frozen_string_literal: true

module Veille
  module Connectors
    # Source 7 — flux RSS des sites officiels des communes du Grand Nancy (hors Nancy, couverte
    # par l'Agenda Grand Nancy). La liste vient de l'annuaire (config/veille/communes_grand_nancy.yml) :
    # ne sont lues que les communes dont le flux est actif et dont les mentions légales
    # n'interdisent pas la réutilisation (Veille::AnnuaireCommunes). Les autres vont à la lecture
    # humaine, /admin/veille/communes. Aucun réseau social n'est appelé.
    #
    # On ne garde que le titre, le lien et l'extrait fourni par le flux (jamais la page entière),
    # pour les articles des 30 derniers jours. Le type (opportunité, histoire) et la catégorie
    # sont laissés à l'enrichissement : beaucoup d'articles communaux sont des informations
    # pratiques, pas des invitations à agir. La source est conservée dans l'URL et l'origine.
    class Communes < Base
      DEPUIS_JOURS = 30
      EXTRAIT_MAX  = 400

      def initialize(communes: Veille::AnnuaireCommunes.automatisables, **opts)
        super(**opts)
        @communes = communes
        @erreurs  = {}
      end

      def origin = "communes"

      # Les flux sont jugés à part : la panne d'un site n'empêche pas de lire les autres.
      # Si tous échouent, l'erreur remonte (statut :erreur ou :refuse du Resultat).
      def collect
        items = @communes.flat_map do |commune|
          items_de(commune)
        rescue Veille::Http::Error => e
          @erreurs[commune.nom] = e
          Rails.logger.warn("[Veille] Communes #{commune.nom} : #{e.message}")
          []
        end
        raise @erreurs.values.first if @communes.any? && @erreurs.size == @communes.size

        items
      end

      def call
        resultat = super
        return resultat if @erreurs.empty? || resultat.statut != :ok

        resultat.message += " ; en échec : #{@erreurs.map { |nom, e| "#{nom} (#{e.message.slice(0, 80)})" }.join(', ')}"
        resultat
      end

      private

      def items_de(commune)
        Nokogiri::XML(http.get(commune.rss)).xpath("//item").filter_map { |noeud| item_pour(noeud, commune) }
      end

      def item_pour(noeud, commune)
        titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
        lien  = noeud.at_xpath("link")&.text.to_s.strip
        return nil if titre.blank? || !lien_de_la_commune?(lien, commune)

        publie = date_de(noeud.at_xpath("pubDate")&.text)
        return nil if publie && publie < today - DEPUIS_JOURS

        extrait = nettoyer(Veille::Text.plain(noeud.at_xpath("description")&.text)).slice(0, EXTRAIT_MAX)
        texte = [titre, extrait.presence, "Source : #{commune.site.sub(%r{\Ahttps?://(www\.)?}, '')}"].compact.join(". ")

        Item.new(origin: origin, url: lien, title: titre, text: texte, published_on: publie,
                 commune: commune.nom, reliability: "moyenne")
      end

      # WordPress ajoute « […] » et « Cet article X est apparu en premier sur Y. » à l'extrait.
      def nettoyer(extrait)
        extrait.sub(/\s*Cet article .{0,200}? est apparu en premier sur .*\z/, "").sub(/\s*\[(…|\.\.\.)\]\s*\z/, "").strip
      end

      # Un lien étranger au site de la commune (publicité, flux détourné) n'entre jamais.
      def lien_de_la_commune?(lien, commune)
        URI.parse(lien).host.to_s.sub(/\Awww\./, "") == URI.parse(commune.site).host.to_s.sub(/\Awww\./, "")
      rescue URI::InvalidURIError
        false
      end

      def date_de(valeur)
        valeur.present? ? Time.zone.parse(valeur.to_s)&.to_date : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
