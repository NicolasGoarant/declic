# frozen_string_literal: true

require "net/http"
require "uri"

module Veille
  # Lit le robots.txt de chaque hôte (une fois par instance) et dit si une URL
  # peut être visitée par notre agent. Règles : groupe « declicveille » s'il
  # existe, sinon « * » ; la règle la plus longue l'emporte, Allow gagne à
  # égalité ; `*` et `$` sont gérés. Un 4xx vaut « tout permis », une panne
  # (5xx, réseau) vaut « interdit » : dans le doute on ne visite pas.
  class RobotsPolicy
    AGENT = "declicveille"

    Regles = Struct.new(:rules, :crawl_delay, keyword_init: true)

    def initialize(fetcher: nil, user_agent: Veille::Http::USER_AGENT)
      @fetcher    = fetcher || method(:fetch_robots)
      @user_agent = user_agent
      @cache      = {}
    end

    def allowed?(url)
      uri = URI.parse(url.to_s)
      regles = regles_pour(uri)
      return false if regles.nil?

      chemin = uri.path.presence || "/"
      chemin += "?#{uri.query}" if uri.query
      self.class.autorise?(regles.rules, chemin)
    end

    def crawl_delay(url)
      regles_pour(URI.parse(url.to_s))&.crawl_delay
    end

    # --- pur : testable sans réseau ---------------------------------------
    def self.parse(texte)
      groupes = []
      courant = nil
      dernier_etait_agent = false

      texte.to_s.each_line do |ligne|
        ligne = ligne.sub(/#.*/, "").strip
        next if ligne.empty?

        cle, valeur = ligne.split(":", 2).map(&:strip)
        next if valeur.nil?

        case cle.downcase
        when "user-agent"
          groupes << (courant = { agents: [], rules: [], delay: nil }) unless dernier_etait_agent && courant
          courant[:agents] << valeur.downcase
          dernier_etait_agent = true
        when "allow", "disallow"
          dernier_etait_agent = false
          next unless courant
          courant[:rules] << [cle.downcase == "allow", valeur] unless valeur.empty? && cle.downcase == "disallow"
        when "crawl-delay"
          dernier_etait_agent = false
          courant[:delay] = valeur.to_f if courant
        else
          dernier_etait_agent = false
        end
      end

      groupe = groupes.find { |g| g[:agents].any? { |a| a != "*" && AGENT.start_with?(a) } } ||
               groupes.find { |g| g[:agents].include?("*") }
      return Regles.new(rules: [], crawl_delay: nil) unless groupe

      Regles.new(rules: groupe[:rules], crawl_delay: groupe[:delay])
    end

    def self.autorise?(rules, chemin)
      meilleure = nil
      rules.each do |permis, motif|
        next unless correspond?(motif, chemin)

        if meilleure.nil? || motif.length > meilleure[1].length ||
           (motif.length == meilleure[1].length && permis)
          meilleure = [permis, motif]
        end
      end
      meilleure.nil? || meilleure[0]
    end

    def self.correspond?(motif, chemin)
      regex = Regexp.escape(motif).gsub("\\*", ".*")
      regex = regex.sub(/\\\$\z/, "\\z")
      chemin.match?(/\A#{regex}/)
    end

    private

    def regles_pour(uri)
      cle = "#{uri.scheme}://#{uri.host}"
      return @cache[cle] if @cache.key?(cle)

      statut, corps = @fetcher.call("#{cle}/robots.txt")
      @cache[cle] =
        case statut
        when 200..299 then self.class.parse(corps)
        when 400..499 then Regles.new(rules: [], crawl_delay: nil)
        end # nil : robots injoignable, on s'abstient
    end

    def fetch_robots(url)
      uri = URI.parse(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: 5, read_timeout: 10) do |http|
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = @user_agent
        http.request(req)
      end
      [res.code.to_i, res.body.to_s.dup.force_encoding("UTF-8").scrub]
    rescue StandardError
      [599, ""]
    end
  end
end
