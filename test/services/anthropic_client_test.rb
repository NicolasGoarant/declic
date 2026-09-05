require "test_helper"

class AnthropicClientTest < ActiveSupport::TestCase
  # Sous-classe de test : remplace la connexion Faraday par l'adaptateur
  # de test intégré à Faraday. Aucune gem de bouchonnage nécessaire.
  class Stubbed < AnthropicClient
    def initialize(stubs:, **kwargs)
      @stubs = stubs
      super(**kwargs)
    end

    private

    def connection
      @connection ||= Faraday.new { |f| f.adapter(:test, @stubs) }
    end
  end

  def build(stubs, **kwargs)
    Stubbed.new(stubs: stubs, api_key: "clef-de-test", model: "modele-de-test", **kwargs)
  end

  def stubs(&block)
    Faraday::Adapter::Test::Stubs.new(&block)
  end

  test "rend le JSON de la réponse sur succès" do
    s = stubs { |b| b.post("/v1/messages") { [200, {}, '{"content":[{"type":"text","text":"salut"}]}'] } }
    response = build(s).messages(messages: [{ role: "user", content: "x" }])

    assert_equal "salut", AnthropicClient.extract_text(response)
  end

  test "un corps 2xx illisible lève MalformedResponseError" do
    s = stubs { |b| b.post("/v1/messages") { [200, {}, "<html>maintenance</html>"] } }

    error = assert_raises(AnthropicClient::MalformedResponseError) do
      build(s).messages(messages: [{ role: "user", content: "x" }])
    end
    assert_kind_of AnthropicClient::Error, error, "doit rester rattrapable comme AnthropicClient::Error"
    assert_match(/illisible/, error.message)
  end

  test "une panne réseau persistante lève ConnectionError et non une erreur Faraday" do
    appels = 0
    s = stubs do |b|
      b.post("/v1/messages") { appels += 1; raise Faraday::ConnectionFailed, "réseau coupé" }
    end

    error = assert_raises(AnthropicClient::ConnectionError) do
      build(s, retries: 1).messages(messages: [{ role: "user", content: "x" }])
    end
    assert_kind_of AnthropicClient::Error, error
    assert_equal 2, appels, "un essai initial plus un retry"
  end

  test "retries: 0 n'effectue aucune seconde tentative — chemin web" do
    appels = 0
    s = stubs do |b|
      b.post("/v1/messages") { appels += 1; raise Faraday::TimeoutError, "trop lent" }
    end

    assert_raises(AnthropicClient::ConnectionError) do
      build(s, retries: 0).messages(messages: [{ role: "user", content: "x" }])
    end
    assert_equal 1, appels, "sur le chemin web un retry ferait sauter le budget Heroku"
  end

  test "401 et 429 ont leurs exceptions dédiées" do
    s401 = stubs { |b| b.post("/v1/messages") { [401, {}, "nope"] } }
    assert_raises(AnthropicClient::AuthenticationError) { build(s401).messages(messages: []) }

    s429 = stubs { |b| b.post("/v1/messages") { [429, {}, "slow down"] } }
    assert_raises(AnthropicClient::RateLimitError) { build(s429).messages(messages: []) }
  end

  test "le modèle est surchargeable par instance et par appel" do
    corps = nil
    s = stubs do |b|
      b.post("/v1/messages") { |env| corps = JSON.parse(env.body); [200, {}, '{"content":[]}'] }
    end

    client = build(s, model: "modele-instance")
    client.messages(messages: [])
    assert_equal "modele-instance", corps["model"]

    client.messages(messages: [], model: "modele-appel")
    assert_equal "modele-appel", corps["model"]
  end

  test "le timeout vaut 20 s par défaut, sous les 30 s d'Heroku" do
    assert_equal 20, AnthropicClient::DEFAULT_TIMEOUT
    assert_operator AnthropicClient::DEFAULT_TIMEOUT, :<, 30
  end
end
