# frozen_string_literal: true

require "net/http"
require "uri"

module Veille
  # Client HTTP de la veille : s'identifie, vérifie le robots.txt de chaque
  # hôte avant toute requête (y compris après redirection), espace les appels
  # vers un même hôte et plafonne la taille lue.
  class Http
    class Error   < StandardError; end
    # robots.txt interdit l'URL (ou n'a pu être lu) : on ne visite pas.
    class Refused < Error; end

    USER_AGENT    = "DeclicVeille/1.0 (+https://declic.site)"
    MAX_REDIRECTS = 3
    MAX_BYTES     = 5_000_000
    DELAI_MIN     = 1.0
    DELAI_MAX     = 10.0

    def initialize(robots: RobotsPolicy.new, sleeper: ->(s) { sleep(s) })
      @robots   = robots
      @sleeper  = sleeper
      @dernier  = {}
    end

    # Corps de la réponse (String UTF-8). `robots: false` seulement pour une
    # API officielle appelée avec clé, qui n'est pas une page web.
    def get(url, headers: {}, robots: true, redirects_left: MAX_REDIRECTS)
      uri = URI.parse(url)
      raise Error, "URL non http(s) : #{url}" unless uri.is_a?(URI::HTTP)
      raise Refused, "robots.txt de #{uri.host} interdit #{uri.path}" if robots && !@robots.allowed?(url)

      patienter(uri, robots ? @robots.crawl_delay(url) : nil)
      res = perform(uri, headers)

      case res
      when Net::HTTPSuccess
        res.body.to_s.byteslice(0, MAX_BYTES).force_encoding("UTF-8").scrub
      when Net::HTTPRedirection
        raise Error, "trop de redirections" if redirects_left.zero?
        get(URI.join(uri, res["location"].to_s).to_s, headers: headers, robots: robots,
                                                      redirects_left: redirects_left - 1)
      else
        raise Error, "HTTP #{res.code} sur #{uri.host}"
      end
    rescue URI::InvalidURIError => e
      raise Error, "URL invalide : #{e.message}"
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, EOFError => e
      raise Error, "#{e.class.name.demodulize} sur #{uri&.host} — #{e.message}"
    end

    private

    def patienter(uri, delai_robots)
      delai = (delai_robots || DELAI_MIN).clamp(DELAI_MIN, DELAI_MAX)
      avant = @dernier[uri.host]
      if avant
        reste = delai - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - avant)
        @sleeper.call(reste) if reste.positive?
      end
      @dernier[uri.host] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def perform(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: 8, read_timeout: 20) do |http|
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"]      = USER_AGENT
        req["Accept-Language"] = "fr"
        headers.each { |k, v| req[k] = v }
        http.request(req)
      end
    end
  end
end
