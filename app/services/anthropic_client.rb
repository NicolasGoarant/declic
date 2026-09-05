# frozen_string_literal: true

require "faraday"
require "json"

# Client minimal pour l'API Anthropic Messages.
#
# Porté depuis la branche ingestion-ia, avec trois correctifs :
#   1. Faraday::ConnectionFailed / TimeoutError et JSON::ParserError sont
#      enveloppées dans AnthropicClient::Error. Auparavant elles fuyaient
#      brutes et les `rescue AnthropicClient::Error` en aval ne les
#      attrapaient pas.
#   2. Le timeout est paramétrable à l'instanciation. Le défaut est 20 s
#      pour laisser une marge sous le timeout Heroku de 30 s, puisque la
#      rédaction se fait dans la requête web (aucun worker dyno).
#   3. Le modèle est surchargeable à l'instanciation ET par appel, ce qui
#      permet Haiku pour la qualification et Sonnet pour la rédaction.
class AnthropicClient
  class Error               < StandardError; end
  class AuthenticationError < Error; end
  class RateLimitError      < Error; end
  # Réseau injoignable / timeout, après le retry. Réessayable.
  class ConnectionError     < Error; end
  # Réponse HTTP 2xx dont le corps n'est pas du JSON exploitable.
  class MalformedResponseError < Error; end

  API_URL         = "https://api.anthropic.com"
  API_VERSION     = "2023-06-01"
  DEFAULT_MAX_TOKENS = 1024

  # 20 s : marge sous le timeout Heroku de 30 s. Un appel lancé depuis une
  # tâche rake peut passer une valeur plus large.
  DEFAULT_TIMEOUT = 20
  OPEN_TIMEOUT    = 10

  attr_reader :model, :timeout, :retries

  # retries : nombre de tentatives SUPPLÉMENTAIRES sur incident réseau.
  # Sur le chemin web, passer 0 — un retry doublerait le temps de réponse
  # et ferait sauter le budget de 30 s d'Heroku.
  def initialize(api_key: nil, model: nil, timeout: DEFAULT_TIMEOUT,
                 open_timeout: OPEN_TIMEOUT, retries: 1)
    cfg           = Rails.configuration.x.anthropic
    @api_key      = api_key || cfg[:api_key]
    @model        = model   || cfg[:model]
    @timeout      = timeout
    @open_timeout = open_timeout
    @retries      = retries
    raise AuthenticationError, "ANTHROPIC_API_KEY manquant" if @api_key.blank?
    raise Error,               "modèle Anthropic manquant"  if @model.blank?
  end

  # Envoi synchrone d'un échange.
  #
  # messages   : tableau de hash { role: "user"|"assistant", content: "..." }
  # system     : prompt système (string optionnelle)
  # max_tokens : max tokens en sortie
  # model      : surcharge ponctuelle du modèle par défaut
  # **extra    : tout paramètre additionnel passé tel quel dans le body
  #              (ex. output_config, tools, tool_choice…).
  #
  # Retourne le hash JSON brut de la réponse Anthropic.
  def messages(messages:, system: nil, max_tokens: DEFAULT_MAX_TOKENS, model: nil, **extra)
    body = {
      model:      model || @model,
      max_tokens: max_tokens,
      messages:   messages
    }
    body[:system] = system if system.present?
    body.merge!(extra)
    request(:post, "/v1/messages", body)
  end

  # Utilitaire : extrait le texte concaténé d'une réponse Messages.
  def self.extract_text(response)
    Array(response["content"]).filter_map { |b| b["text"] if b["type"] == "text" }.join
  end

  private

  def request(method, path, body)
    resp = retry_once { connection.public_send(method, path, body.to_json) }

    case resp.status
    when 200..299
      parse_body(resp.body)
    when 401
      raise AuthenticationError, "401 — clé API invalide ou expirée"
    when 429
      raise RateLimitError,      "429 — rate limit Anthropic, ralentir"
    else
      raise Error, "HTTP #{resp.status} — #{resp.body.to_s[0, 500]}"
    end
  end

  # Un 2xx au corps illisible est une réponse mal formée, pas une panne
  # réseau : on remonte une exception explicite plutôt qu'une
  # JSON::ParserError nue que personne n'attrape en aval.
  def parse_body(raw)
    JSON.parse(raw)
  rescue JSON::ParserError, TypeError => e
    raise MalformedResponseError,
          "réponse Anthropic illisible (#{e.class}) — #{raw.to_s[0, 300]}"
  end

  def connection
    @connection ||= Faraday.new(url: API_URL) do |f|
      f.headers["x-api-key"]         = @api_key
      f.headers["anthropic-version"] = API_VERSION
      f.headers["content-type"]      = "application/json"
      f.options.timeout              = @timeout
      f.options.open_timeout         = @open_timeout
    end
  end

  # Retente au plus @retries fois sur incident réseau. Une fois les essais
  # épuisés, on enveloppe dans ConnectionError : l'appelant ne doit jamais
  # avoir à connaître Faraday.
  def retry_once
    attempts = 0
    begin
      attempts += 1
      yield
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      if attempts <= @retries
        Rails.logger.warn("[AnthropicClient] #{e.class}: #{e.message} — retry #{attempts}/#{@retries}")
        retry
      end
      raise ConnectionError, "API Anthropic injoignable (#{e.class}) — #{e.message}"
    rescue Faraday::Error => e
      raise ConnectionError, "erreur transport Faraday (#{e.class}) — #{e.message}"
    end
  end
end
