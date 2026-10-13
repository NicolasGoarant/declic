# frozen_string_literal: true

module Veille
  module Connectors
    # Source 3 — Pôle formation UIMM Lorraine (formation-industries-lorraine.com,
    # robots.txt permissif sauf /search, /admin…). On lit le sitemap, on visite les
    # pages dont l'adresse parle de formation, et on garde celles qui citent une
    # commune du Grand Nancy.
    #
    # formation.grandest.fr n'est PAS branché : c'est une application Angular dont
    # l'API (base inconnue, non publiée) ne répond pas depuis l'extérieur. Voir
    # docs/veille-auto.md.
    class FormationLorraine < Base
      SITEMAP = "https://www.formation-industries-lorraine.com/sitemap.xml"
      MOTIF   = %r{/(formation|cap|bac-pro|bts|licence|master|titre|cqp|bachelor|diplome|alternance)[a-z0-9\-]*}i
      MAX_PAGES = 25

      def origin = "formation"

      def collect
        urls = Nokogiri::XML(http.get(SITEMAP)).remove_namespaces!.xpath("//url/loc").map(&:text)
        # Les pages déjà connues ne sont pas relues : chaque exécution avance dans le sitemap.
        urls = urls.select { |u| URI(u).path.match?(MOTIF) }.reject { |u| Veille::Candidate.exists?(url: u) }.first(MAX_PAGES)
        urls.filter_map { |u| item_pour(u) }
      end

      def item_pour(url)
        html = http.get(url)
        page = Veille::PageFetcher.extract(html, url: url)
        doc = Nokogiri::HTML(html)
        texte = Veille::Text.plain(doc.at_css("main, article, body")&.text.to_s).slice(0, 4000)
        commune = Veille::GrandNancy.trouver_dans("#{page[:title]} #{texte}")
        return nil unless commune

        Item.new(origin: origin, url: url, title: page[:title], text: texte, published_on: page[:published_on],
                 schedule_text: "Formation : consulter les prochaines sessions", commune: commune,
                 category_hint: "formation", type_hint: "opportunite", reliability: "haute")
      rescue Veille::Http::Error => e
        raise e if e.is_a?(Veille::Http::Refused)
        nil
      end
    end
  end
end
