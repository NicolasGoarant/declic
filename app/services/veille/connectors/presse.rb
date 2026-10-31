# frozen_string_literal: true

module Veille
  module Connectors
    # Source 6 — flux RSS de la presse locale (quotidienne : chaque flux ne garde que 20 articles, soit quelques heures à un jour). Le flux n'est lu
    # que si son robots.txt l'autorise ; on ne visite AUCUN article : seuls
    # titre, chapeau, date et lien du flux sont gardés. Un article est retenu si
    # son titre ou chapeau cite une commune du Grand Est ; la suite (type,
    # mise hors ligne) revient à l'enrichissement IA. Un article présent dans
    # plusieurs flux est dédoublonné par son URL à l'ingestion.
    class Presse < Base
      FLUX = {
        "L'Est Républicain"     => "https://www.estrepublicain.fr/rss",
        "L'Est Républicain, édition de Nancy" => "https://www.estrepublicain.fr/edition-nancy-et-agglomeration/rss",
        "L'Est Républicain, rubrique Société" => "https://www.estrepublicain.fr/societe/rss",
        "France 3 Grand Est"    => "https://france3-regions.francetvinfo.fr/grand-est/rss?r=grand-est"
      }.freeze

      def initialize(flux: FLUX, **opts)
        super(**opts)
        @flux = flux
      end

      def origin = "presse"

      # Chaque flux est jugé à part : le refus de l'un (robots.txt) n'empêche pas
      # de lire les autres. Statut :partiel si certains seulement répondent.
      def call
        @etat = {}
        items = @flux.flat_map { |nom, url| lire_flux(nom, url) }
        refuses = @etat.select { |_, (st, _)| st != :ok }
        return super_resultat(items) if refuses.empty?

        detail = @etat.map { |nom, (st, msg)| "#{nom} : #{st == :ok ? 'ok' : "#{st} (#{msg})"}" }.join(" ; ")
        statut = refuses.size == @etat.size ? refuses.values.first.first : :partiel
        Resultat.new(nom: nom, statut: statut, items: items, message: detail)
      end

      def collect = @flux.flat_map { |nom, url| lire_flux(nom, url) }

      def lire_flux(nom, url)
        items = Nokogiri::XML(http.get(url)).xpath("//item").filter_map { |n| item_pour(n, nom) }
        @etat[nom] = [:ok, nil] if @etat
        items
      rescue Veille::Http::Refused => e
        @etat[nom] = [:refuse, e.message] if @etat
        []
      rescue Veille::Http::Error => e
        @etat[nom] = [:erreur, e.message] if @etat
        []
      end

      def super_resultat(items)
        Resultat.new(nom: nom, statut: :ok, items: items, message: "#{items.size} élément(s) retenu(s)")
      end

      def item_pour(noeud, nom_flux)
        titre = Veille::Text.plain(noeud.at_xpath("title")&.text)
        chapeau = Veille::Text.plain(noeud.at_xpath("description")&.text).slice(0, 600)
        lien = noeud.at_xpath("link")&.text.to_s.strip
        brut = "#{titre} #{chapeau}"
        commune = Veille::Territoire.trouver_dans(brut) or return nil

        Item.new(origin: origin, url: lien, title: titre, text: "#{nom_flux}. #{chapeau}",
                 published_on: parse_date(noeud.at_xpath("pubDate")&.text), commune: commune,
                 type_hint: nil, reliability: "moyenne")
      end
    end
  end
end
