require "test_helper"
require_relative "../support"

class Veille::ConnectorsTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)

  def fixture(nom) = File.read(Rails.root.join("test/fixtures/files/veille", nom))

  # --- Agenda du Grand Nancy ---------------------------------------------------
  test "agenda : garde les rubriques utiles, écarte spectacles, hors zone et passé" do
    http = FakeHttp.new("https://agenda-integration.grandnancy.eu/api/vdn/events" => fixture("agenda_extrait.json"))
    res = Veille::Connectors::AgendaNancy.new(http: http, today: TODAY).call

    assert_equal :ok, res.statut
    assert_equal ["Les Rêveurs, film d'Isabelle Carré", "Don de sang festif"], res.items.map(&:title)

    don = res.items.last
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

  test "transentreprise : ne garde que l'arrondissement de Nancy, texte réduit à l'accroche" do
    http = FakeHttp.new("https://www.transentreprise.com/rss/offre" => RSS_TE)
    res = Veille::Connectors::Transentreprise.new(http: http, today: TODAY).call

    assert_equal 1, res.items.size
    offre = res.items.first
    assert_equal "BOULANGERIE-PÂTISSERIE", offre.title
    assert_equal "entreprendre", offre.category_hint
    assert_equal "Belle affaire établie", offre.text
    assert_includes offre.url, "nancy-et-arrondissement"
  end

  # --- Presse ------------------------------------------------------------------
  RSS_PRESSE = <<~XML
    <rss version="2.0"><channel>
      <item><title>Portrait : à Laxou, Awa a relancé la cantine solidaire</title><description>Une initiative de quartier.</description>
        <link>https://presse.example/portrait-awa</link><pubDate>Mon, 12 Oct 2026 08:00:00 +0200</pubDate></item>
      <item><title>Football : le SLUC s'incline à Nancy</title><description>Match nul.</description><link>https://presse.example/foot</link></item>
      <item><title>Portrait d'un boulanger de Metz</title><description>Reportage.</description><link>https://presse.example/metz</link></item>
    </channel></rss>
  XML

  test "presse : ne retient que « commune du Grand Nancy + sujet », via le flux seul" do
    http = FakeHttp.new("https://presse.example/rss" => RSS_PRESSE)
    res = Veille::Connectors::Presse.new(flux: { "Presse test" => "https://presse.example/rss" }, http: http, today: TODAY).call

    assert_equal ["https://presse.example/portrait-awa"], res.items.map(&:url)
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
    assert_equal 1, res.items.size
    assert_match(/Fermée : refuse/, res.message)
  end

  # --- Gazette -----------------------------------------------------------------
  test "gazette : lit la rubrique puis les articles qui citent une commune du Grand Nancy" do
    rubrique = '<a href="/article/a-nancy">a</a><a href="/article/ailleurs">b</a><a href="/article/a-nancy">dup</a>'
    page = ->(titre) { %(<html><head><meta property="og:title" content="#{titre}"><meta property="og:description" content="Un chapeau."></head></html>) }
    http = FakeHttp.new(
      "https://www.lagazettefrance.fr/meurthe-et-moselle" => rubrique,
      "https://www.lagazettefrance.fr/article/a-nancy" => page.("Un forum de l'emploi à Nancy"),
      "https://www.lagazettefrance.fr/article/ailleurs" => page.("Une usine à Épinal")
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

  # --- Formation ---------------------------------------------------------------
  test "formation : visite les pages de formation qui citent le Grand Nancy" do
    sitemap = <<~XML
      <urlset><url><loc>https://www.formation-industries-lorraine.com/formation-soudeur</loc></url>
      <url><loc>https://www.formation-industries-lorraine.com/mentions-legales</loc></url>
      <url><loc>https://www.formation-industries-lorraine.com/formation-metz</loc></url></urlset>
    XML
    page = ->(titre, corps) { "<html><head><title>#{titre}</title></head><body><main>#{corps}</main></body></html>" }
    http = FakeHttp.new(
      "https://www.formation-industries-lorraine.com/sitemap.xml" => sitemap,
      "https://www.formation-industries-lorraine.com/formation-soudeur" => page.("Soudeur", "Formation au centre de Maxéville, rentrée 2027."),
      "https://www.formation-industries-lorraine.com/formation-metz" => page.("Fraiseur", "Centre de Metz.")
    )
    res = Veille::Connectors::FormationLorraine.new(http: http, today: TODAY).call

    assert_equal ["Soudeur"], res.items.map(&:title)
    assert_equal "Maxéville", res.items.first.commune
    assert_equal "formation", res.items.first.category_hint
    assert_not_includes http.appels, "https://www.formation-industries-lorraine.com/mentions-legales"
  end
end
