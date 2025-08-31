require "net/http"
require "json"

class EngagementApi
  class Error < StandardError; end

  def initialize(base: Rails.configuration.x.engagement_api[:base_url],
                 api_key: Rails.configuration.x.engagement_api[:api_key])
    @base    = base
    @api_key = api_key or raise Error, "ENGAGEMENT_API_KEY manquant"
  end

  # GET /mission ou /mission/search
  def get(path, params = {})
    uri = URI.join(@base + "/", path.sub(%r{^/}, ""))
    uri.query = URI.encode_www_form(params.compact)

    req = Net::HTTP::Get.new(uri)
    # Auth principale : x-api-key (doc officielle)
    req["x-api-key"] = @api_key

    res = perform(req)
    if res.is_a?(Net::HTTPUnauthorized)
      # fallback si la passerelle attend "Bearer <clé>"
      req["x-api-key"] = "Bearer #{@api_key}"
      res = perform(req)
    end

    raise Error, "HTTP #{res.code} #{res.message} — #{res.body&.slice(0,200)}" \
      unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end

  private

  def perform(req)
    Net::HTTP.start(req.uri.hostname, req.uri.port, use_ssl: true,
                    open_timeout: 5, read_timeout: 15) do |http|
      http.request(req)
    end
  end
end
