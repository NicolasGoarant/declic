require "test_helper"

class Veille::RobotsPolicyTest < ActiveSupport::TestCase
  ROBOTS = <<~TXT
    # commentaire
    User-agent: *
    Crawl-delay: 10
    Disallow: /*?*
    Disallow: /login
    Allow: /login/aide

    User-agent: Googlebot
    Disallow: /
  TXT

  def policy(statut: 200, corps: ROBOTS)
    Veille::RobotsPolicy.new(fetcher: ->(_url) { [statut, corps] })
  end

  test "applique le groupe * et la règle la plus longue" do
    p = policy
    assert p.allowed?("https://exemple.fr/missions")
    assert_not p.allowed?("https://exemple.fr/login")
    assert p.allowed?("https://exemple.fr/login/aide")
  end

  test "gère le joker * : les adresses à paramètres sont interdites" do
    assert_not policy.allowed?("https://exemple.fr/missions?page=2")
  end

  test "ignore les groupes d'autres robots" do
    assert policy.allowed?("https://exemple.fr/missions") # Googlebot est exclu, pas nous
  end

  test "un groupe nommé declicveille l'emporte sur *" do
    corps = "User-agent: *\nDisallow: /\n\nUser-agent: DeclicVeille\nDisallow: /prive\n"
    p = policy(corps: corps)
    assert p.allowed?("https://exemple.fr/public")
    assert_not p.allowed?("https://exemple.fr/prive/x")
  end

  test "expose le Crawl-delay" do
    assert_equal 10.0, policy.crawl_delay("https://exemple.fr/")
  end

  test "pas de robots.txt (404) : tout est permis" do
    assert policy(statut: 404, corps: "").allowed?("https://exemple.fr/n-importe-quoi")
  end

  test "robots.txt injoignable (5xx) : on s'abstient" do
    assert_not policy(statut: 503, corps: "").allowed?("https://exemple.fr/page")
  end

  test "Disallow: vide ne bloque rien" do
    assert policy(corps: "User-agent: *\nDisallow:\n").allowed?("https://exemple.fr/tout")
  end

  test "le client HTTP refuse une URL interdite sans la requêter" do
    http = Veille::Http.new(robots: policy, sleeper: ->(_) {})
    assert_raises(Veille::Http::Refused) { http.get("https://exemple.fr/login") }
  end
end
