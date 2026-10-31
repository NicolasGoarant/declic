require "test_helper"
require_relative "../support"

class Veille::ConnectorsTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)

  def fixture(nom) = File.read(Rails.root.join("test/fixtures/files/veille", nom))

  # --- Agenda du Grand Nancy ---------------------------------------------------
  test "agenda : un événement hors Meurthe-et-Moselle est écarté" do
    ev = { "name" => "À Metz", "mainCategory" => { "name" => "Citoyenneté" }, "uuid" => "x",
           "startDate" => "2026-11-02", "place" => { "city" => { "name" => "Metz" } } }
    assert_nil Veille::Connectors::AgendaNancy.new(http: FakeHttp.new, today: TODAY).item_pour(ev)
  end

  test "agenda : garde les rubriques utiles, écarte spectacles et passé" do
    http = FakeHttp.new("https://agenda-integration.grandnancy.eu/api/vdn/events" => fixture("agenda_extrait.json"))
    res = Veille::Connectors::AgendaNancy.new(http: http, today: TODAY).call

    assert_equal :ok, res.statut
    assert_equal ["Les Rêveurs, film d'Isabelle Carré", "Don de sang festif", "Rencontre à Toul"], res.items.map(&:title),
                 "Toul est en Meurthe-et-Moselle : l'événement reste dans le périmètre"

    don = res.items.find { |i| i.title == "Don de sang festif" }
    assert_equal "benevolat", don.category_hint, "« Citoyenneté » mène à S'engager"
    assert_equal "opportunite", don.type_hint
    assert_equal "Nancy", don.commune
    assert_equal Date.new(2026, 10, 16), don.starts_on
    assert_match %r{\Ahttps://www\.nancy\.fr/agenda/details-agenda\?uuid=}, don.url
  end

  # --- JeVeuxAider / API Engagement --------------------------------------------
  class FakeApi
    attr_reader :params
    def get(path, params) = (@params = params; @reponse)
    def initialize(reponse) = @reponse = reponse
  end

  test "engagement : missions à 15 km de Nancy, régime « ouvert toute l'année » sans date" do
    api = FakeApi.new("data" => [
      { "_id" => "1", "title" => "Aide aux devoirs", "organizationName" => "Asso X", "description" => "<p>Accompagner des collégiens.</p>",
        "applicationUrl" => "https://www.jeveuxaider.gouv.fr/m/1", "addresses" => [{ "city" => "Nancy" }] },
      { "_id" => "2", "title" => "Maraude", "applicationUrl" => "https://www.jeveuxaider.gouv.fr/m/2",
        "addresses" => [{ "city" => "Toul" }], "startAt" => "2026-11-02T00:00:00Z", "endAt" => "2026-12-01T00:00:00Z" },
      { "_id" => "3", "title" => "Terminée", "applicationUrl" => "https://www.jeveuxaider.gouv.fr/m/3",
        "addresses" => [{ "city" => "Nancy" }], "endAt" => "2026-09-01T00:00:00Z" }
    ])
    res = Veille::Connectors::Engagement.new(api: api, http: FakeHttp.new, today: TODAY).call

    assert_equal "15km", api.params[:distance]
    assert_in_delta 48.69, api.params[:lat], 0.01
    assert_equal %w[Aide\ aux\ devoirs Maraude], res.items.map(&:title), "la mission terminée est écartée"

    aide = res.items.first
    assert_equal "Ouvert toute l'année", aide.schedule_text
    assert_equal "benevolat", aide.category_hint
    assert_includes aide.text, "Accompagner des collégiens."
    assert_nil res.items.last.schedule_text, "une mission datée n'a pas de régime"
  end

  test "engagement : sans clé d'API, la source est signalée inactive" do
    api = Object.new
    api.define_singleton_method(:get) { |*| raise EngagementApi::Error, "ENGAGEMENT_API_KEY manquant" }
    res = Veille::Connectors::Engagement.new(api: api, http: FakeHttp.new, today: TODAY).call
    assert_equal :inactive, res.statut
    assert_match(/ENGAGEMENT_API_KEY/, res.message)
  end

  # --- Transentreprise ---------------------------------------------------------
  RSS_TE = <<~XML
    <rss version="2.0"><channel>
      <item><title><![CDATA[BOULANGERIE-PÂTISSERIE]]></title>
        <description><![CDATA[<ul><li>Belle affaire &eacute;tablie</li></ul>]]></description>
        <pubDate><![CDATA[Tue, 13 Oct 2026 00:00:00 +0200]]></pubDate>
        <link>https://www.transentreprise.com/offres/fiche/GES1H/boulangerie/grand-est/meurthe-et-moselle/nancy-et-arrondissement</link></item>
      <item><title>Café</title><description>x</description>
        <link>https://www.transentreprise.com/offres/fiche/ARA2H/cafe/auvergne-rhone-alpes/cantal/mauriac</link></item>
    </channel></rss>
  XML

  test "transentreprise : garde la Meurthe-et-Moselle, commune tirée de l'annonce ou de l'arrondissement" do
    rss = <<~XML
      <rss><channel>
        <item><title>Garage à Baccarat</title><description>x</description>
          <link>https://www.transentreprise.com/offres/fiche/A/garage/grand-est/meurthe-et-moselle/arr-de-luneville</link></item>
        <item><title>Bar-tabac</title><description>x</description>
          <link>https://www.transentreprise.com/offres/fiche/B/bar/grand-est/meurthe-et-moselle/arr-de-toul</link></item>
      </channel></rss>
    XML
    http = FakeHttp.new("https://www.transentreprise.com/rss/offre" => rss)
    res = Veille::Connectors::Transentreprise.new(http: http, today: TODAY).call
    assert_equal %w[Baccarat Toul], res.items.map(&:commune)
  end

  test "transentreprise : écarte les autres départements, texte réduit à l'accroche" do
    http = FakeHttp.new("https://www.transentreprise.com/rss/offre" => RSS_TE)
    res = Veille::Connectors::Transentreprise.new(http: http, today: TODAY).call

    assert_equal 1, res.items.size
    offre = res.items.first
    assert_equal "BOULANGERIE-PÂTISSERIE", offre.title
    assert_equal "entreprendre", offre.category_hint
    assert_equal "Belle affaire établie", offre.text
    assert_includes offre.url, "nancy-et-arrondissement"
    assert_equal "Nancy", offre.commune
  end

  # --- Presse ------------------------------------------------------------------
  RSS_PRESSE = <<~XML
    <rss version="2.0"><channel>
      <item><title>Portrait : à Laxou, Awa a relancé la cantine solidaire</title><description>Une initiative de quartier.</description>
        <link>https://presse.example/portrait-awa</link><pubDate>Mon, 12 Oct 2026 08:00:00 +0200</pubDate></item>
      <item><title>Football : le SLUC s'incline à Nancy</title><description>Match nul.</description><link>https://presse.example/foot</link></item>
      <item><title>Portrait d'un boulanger de Besançon</title><description>Reportage.</description><link>https://presse.example/besancon</link></item>
    </channel></rss>
  XML

  test "presse : un article sur une commune du Grand Est hors Métropole est retenu" do
    rss = "<rss><channel><item><title>Elle ouvre sa boutique à Épinal</title><description>Récit.</description><link>https://presse.example/e</link></item></channel></rss>"
    http = FakeHttp.new("https://presse.example/rss" => rss)
    res = Veille::Connectors::Presse.new(flux: { "Presse test" => "https://presse.example/rss" }, http: http, today: TODAY).call
    assert_equal ["Épinal"], res.items.map(&:commune)
  end

  test "presse : retient tout article qui cite une commune du Grand Est, via le flux seul" do
    http = FakeHttp.new("https://presse.example/rss" => RSS_PRESSE)
    res = Veille::Connectors::Presse.new(flux: { "Presse test" => "https://presse.example/rss" }, http: http, today: TODAY).call

    assert_equal ["https://presse.example/portrait-awa", "https://presse.example/foot"], res.items.map(&:url),
                 "le sujet est laissé à l'IA ; seul l'article sur Besançon est hors zone"
    assert_equal ["https://presse.example/rss"], http.appels, "aucun article n'est visité"
    assert_equal "Laxou", res.items.first.commune
    assert_equal "moyenne", res.items.first.reliability
    assert_nil res.items.first.type_hint, "le type est laissé à l'IA"
  end

  test "presse : un flux refusé n'empêche pas de lire l'autre (statut partiel)" do
    http = FakeHttp.new("https://presse.example/rss" => RSS_PRESSE,
                        "https://refuse.example/rss" => Veille::Http::Refused.new("robots.txt interdit /rss"))
    res = Veille::Connectors::Presse.new(flux: { "Ouverte" => "https://presse.example/rss", "Fermée" => "https://refuse.example/rss" },
                                         http: http, today: TODAY).call

    assert_equal :partiel, res.statut
    assert_equal 2, res.items.size
    assert_match(/Fermée : refuse/, res.message)
  end

  test "presse : lue chaque jour avec les autres sources" do
    assert_includes Veille::Runner::QUOTIDIEN, Veille::Connectors::Presse
  end

  test "presse : les flux de L'Est Républicain sont configurés" do
    urls = Veille::Connectors::Presse::FLUX.values
    assert_includes urls, "https://www.estrepublicain.fr/edition-nancy-et-agglomeration/rss"
    assert_includes urls, "https://www.estrepublicain.fr/societe/rss"
  end

  test "presse : un article présent dans deux flux ne crée qu'un candidat" do
    http = FakeHttp.new("https://a.example/rss" => RSS_PRESSE, "https://b.example/rss" => RSS_PRESSE)
    res = Veille::Connectors::Presse.new(flux: { "A" => "https://a.example/rss", "B" => "https://b.example/rss" }, http: http, today: TODAY).call
    assert_equal 4, res.items.size

    bilan = Veille::RawIngester.new(today: TODAY).ingest(res.items)
    assert_equal 2, bilan.crees.size
    assert_equal 2, bilan.doublons
  end

  # --- Gazette -----------------------------------------------------------------
  test "gazette : lit la rubrique puis les articles qui citent une commune du Grand Est" do
    rubrique = '<a href="/article/a-nancy">a</a><a href="/article/ailleurs">b</a><a href="/article/a-nancy">dup</a>'
    page = ->(titre) { %(<html><head><meta property="og:title" content="#{titre}"><meta property="og:description" content="Un chapeau."></head></html>) }
    http = FakeHttp.new(
      "https://www.lagazettefrance.fr/meurthe-et-moselle" => rubrique,
      "https://www.lagazettefrance.fr/article/a-nancy" => page.("Un forum de l'emploi à Nancy"),
      "https://www.lagazettefrance.fr/article/ailleurs" => page.("Une usine à Besançon")
    )
    res = Veille::Connectors::GazetteFrance.new(http: http, today: TODAY).call

    assert_equal ["Un forum de l'emploi à Nancy"], res.items.map(&:title)
    assert_equal "Nancy", res.items.first.commune
  end

  # --- Refus d'accès -----------------------------------------------------------
  test "une source dont robots.txt refuse l'accès est signalée « refusée » et rien n'est lu" do
    http = FakeHttp.new("https://www.transentreprise.com/rss/offre" => Veille::Http::Refused.new("robots.txt interdit"))
    res = Veille::Connectors::Transentreprise.new(http: http, today: TODAY).call
    assert_equal :refuse, res.statut
    assert_empty res.items
  end

  test "une panne réseau est signalée en erreur, sans lever" do
    http = FakeHttp.new("https://www.transentreprise.com/rss/offre" => Veille::Http::Error.new("HTTP 503"))
    res = Veille::Connectors::Transentreprise.new(http: http, today: TODAY).call
    assert_equal :erreur, res.statut
  end
end
