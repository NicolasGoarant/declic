# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "nokogiri"

module Veille
  # Récupère une page publique et en extrait les métadonnées éditoriales
  # (Open Graph puis JSON-LD, avec repli sur les balises HTML classiques).
  #
  # Nokogiri et Net::HTTP suffisent : aucune gem supplémentaire.
  #
  # #fetch fait le réseau ; .extract est pure et se teste sur du HTML brut.
  class PageFetcher
    class Error < StandardError; end

    # S'identifie explicitement, avec l'adresse du site, pour que les
    # éditeurs puissent nous reconnaître dans leurs logs.
    USER_AGENT    = "DeclicVeille/1.0 (+https://declic.site)"
    MAX_REDIRECTS = 3
    TIMEOUT       = 10
    # Au-delà, on ne lit pas : une page d'article n'a aucune raison d'être
    # aussi lourde, et on ne veut pas charger un PDF ou une vidéo.
    MAX_BYTES = 2_000_000

    JSON_LD_TYPES = %w[Article NewsArticle ReportageNewsArticle BlogPosting WebPage].freeze

    # Retourne { title:, excerpt:, published_on:, source_id: }
    def fetch(url)
      html = get(url)
      data = self.class.extract(html, url: url)
      data.merge(source_id: source_id_for(url))
    end

    # ------------------------------------------------------------------
    # Extraction — pure, sans réseau ni base.
    # ------------------------------------------------------------------
    def self.extract(html, url: nil)
      doc = Nokogiri::HTML(html.to_s)
      ld  = json_ld_article(doc)

      {
        title:        first_present(
                        meta(doc, property: "og:title"),
                        meta(doc, name: "twitter:title"),
                        ld["headline"],
                        doc.at_css("title")&.text
                      )&.squish&.slice(0, 250),
        excerpt:      first_present(
                        meta(doc, property: "og:description"),
                        meta(doc, name: "twitter:description"),
                        ld["description"],
                        meta(doc, name: "description")
                      )&.squish,
        published_on: parse_date(first_present(
                        meta(doc, property: "article:published_time"),
                        meta(doc, property: "og:article:published_time"),
                        ld["datePublished"],
                        meta(doc, name: "date"),
                        doc.at_css("time[datetime]")&.[]("datetime")
                      )),
        url:          url
      }
    end

    def self.meta(doc, property: nil, name: nil)
      selector = property ? %(meta[property="#{property}"]) : %(meta[name="#{name}"])
      doc.at_css(selector)&.[]("content")
    end

    def self.first_present(*values)
      values.compact.map { |v| v.to_s.strip }.find(&:present?)
    end

    # Cherche le premier bloc JSON-LD ressemblant à un article. Les pages
    # de presse en empilent souvent plusieurs (fil d'Ariane, organisation…).
    def self.json_ld_article(doc)
      doc.css('script[type="application/ld+json"]').each do |script|
        parsed = JSON.parse(script.text) rescue next
        candidates = flatten_ld(parsed)
        found = candidates.find { |h| Array(h["@type"]).intersect?(JSON_LD_TYPES) }
        return found if found
      end
      {}
    end

    def self.flatten_ld(node)
      case node
      when Array then node.flat_map { |n| flatten_ld(n) }
      when Hash  then [node] + flatten_ld(node["@graph"] || [])
      else []
      end
    end

    def self.parse_date(value)
      return nil if value.blank?
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    private

    def get(url, redirects_left = MAX_REDIRECTS)
      uri = URI.parse(url)
      raise Error, "URL non http(s) : #{url}" unless uri.is_a?(URI::HTTP)

      response = perform(uri)

      case response
      when Net::HTTPSuccess
        body_of(response)
      when Net::HTTPRedirection
        raise Error, "trop de redirections" if redirects_left.zero?

        target = URI.join(uri, response["location"].to_s).to_s
        get(target, redirects_left - 1)
      else
        raise Error, "HTTP #{response.code}"
      end
    rescue URI::InvalidURIError => e
      raise Error, "URL invalide : #{e.message}"
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
           OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError => e
      raise Error, "#{e.class.name.demodulize} — #{e.message}"
    end

    def perform(uri)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl:      uri.scheme == "https",
                      open_timeout: TIMEOUT,
                      read_timeout: TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"]      = USER_AGENT
        request["Accept"]          = "text/html,application/xhtml+xml"
        request["Accept-Language"] = "fr"
        http.request(request)
      end
    end

    def body_of(response)
      type = response["content-type"].to_s
      raise Error, "type de contenu inattendu : #{type.split(';').first}" unless type.include?("html")

      body = response.body.to_s
      body.length > MAX_BYTES ? body[0, MAX_BYTES] : body
    end

    # Rattache le candidat à une source enregistrée si l'hôte correspond.
    def source_id_for(url)
      host = URI.parse(url).host.to_s.delete_prefix("www.")
      return nil if host.blank?

      Veille::Source.find_each do |source|
        source_host = URI.parse(source.url).host.to_s.delete_prefix("www.") rescue next
        return source.id if source_host.present? && source_host.casecmp?(host)
      end
      nil
    rescue URI::InvalidURIError
      nil
    end
  end
end
