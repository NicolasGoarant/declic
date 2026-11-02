require "test_helper"
require_relative "../support"

class Veille::ConnectorsCommunesTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 10, 13)
  FLUX_PULNOY = "https://www.pulnoy.fr/feed/"

  def flux = File.read(Rails.root.join("test/fixtures/files/veille/commune_flux.xml"))

  def pulnoy = Veille::AnnuaireCommunes.par_nom("Pulnoy")

  # --- annuaire ---------------------------------------------------------------
  test "annuaire : les 19 communes du Grand Nancy hors Nancy, ni plus ni moins" do
    noms = Veille::AnnuaireCommunes.toutes.map(&:nom)
    assert_equal 19, noms.size
    assert_equal (Veille::GrandNancy::COMMUNES - ["Nancy"]).sort, noms.sort
  end

  test "annuaire : toute commune a un site, et toute commune à flux déclaré a une URL de flux" do
    Veille::AnnuaireCommunes.toutes.each do |c|
      assert_match %r{\Ahttps?://}, c.site, c.nom
      assert_match %r{\Ahttps?://}, c.rss, c.nom if c.flux_actif
    end
  end

  test "annuaire : une commune à réutilisation restreinte n'est jamais lue par le connecteur" do
    Tempfile.create(["annuaire", ".yml"]) do |f|
      f.write({ "communes" => [
        { "nom" => "Ludres", "site" => "https://www.ludres.com", "rss" => "https://www.ludres.com/feed/", "flux_actif" => true, "reutilisation" => "restreinte" },
        { "nom" => "Pulnoy", "site" => "https://www.pulnoy.fr", "rss" => FLUX_PULNOY, "flux_actif" => true, "reutilisation" => "autorisee" }
      ] }.to_yaml)
      f.flush
      assert_equal ["Pulnoy"], Veille::AnnuaireCommunes.automatisables(fichier: f.path).map(&:nom)
      assert_equal ["Ludres"], Veille::AnnuaireCommunes.manuelles(fichier: f.path).map(&:nom)
    end
  end

  test "annuaire : les 8 communes à lire sont celles décidées au 02/11/2026" do
    assert_equal ["Art-sur-Meurthe", "Jarville-la-Malgrange", "Laneuveville-devant-Nancy", "Ludres", "Maxéville", "Pulnoy",
                  "Saulxures-lès-Nancy", "Vandœuvre-lès-Nancy"], Veille::AnnuaireCommunes.automatisables.map(&:nom).sort
    assert_equal 11, Veille::AnnuaireCommunes.manuelles.size
    assert_equal "autorisee_par_decision", Veille::AnnuaireCommunes.par_nom("Ludres").reutilisation
  end

  test "annuaire : automatisables et manuelles se partagent les 19 communes" do
    auto = Veille::AnnuaireCommunes.automatisables.map(&:nom)
    manuel = Veille::AnnuaireCommunes.manuelles.map(&:nom)
    assert_empty auto & manuel
    assert_equal 19, auto.size + manuel.size
    assert_includes auto, "Pulnoy"
  end

  # --- connecteur -------------------------------------------------------------
  test "lit le flux : garde le récent, écarte l'ancien, le titre vide et le lien étranger" do
    http = FakeHttp.new(FLUX_PULNOY => flux)
    res = Veille::Connectors::Communes.new(communes: [pulnoy], http: http, today: TODAY).call

    assert_equal :ok, res.statut
    assert_equal ["Marché de Noël – samedi 12 décembre"], res.items.map(&:title)
    marche = res.items.first
    assert_equal "communes", marche.origin
    assert_equal "Pulnoy", marche.commune
    assert_equal "https://www.pulnoy.fr/marche-de-noel/", marche.url
    assert_equal Date.new(2026, 10, 12), marche.published_on
    assert_nil marche.type_hint, "le type est laissé à l'enrichissement"
    assert_includes marche.text, "Venez nombreux au marché de Noël, salle des fêtes."
    assert_includes marche.text, "Source : pulnoy.fr"
    assert_no_match(/apparu en premier/, marche.text, "le pied de page WordPress est retiré")
    assert_equal [FLUX_PULNOY], http.appels
  end

  test "la panne d'un flux n'empêche pas de lire les autres, et elle est signalée" do
    autre = pulnoy.dup.tap { |c| c.nom = "Maxéville"; c.site = "https://maxeville.fr"; c.rss = "https://maxeville.fr/index.php/feed/" }
    http = FakeHttp.new(FLUX_PULNOY => flux, autre.rss => Veille::Http::Error.new("HTTP 500 sur maxeville.fr"))
    res = Veille::Connectors::Communes.new(communes: [pulnoy, autre], http: http, today: TODAY).call

    assert_equal :ok, res.statut
    assert_equal 1, res.items.size
    assert_match(/en échec : Maxéville/, res.message)
  end

  test "tous les flux en panne : le résultat est une erreur, pas un succès vide" do
    http = FakeHttp.new(FLUX_PULNOY => Veille::Http::Error.new("HTTP 503 sur www.pulnoy.fr"))
    res = Veille::Connectors::Communes.new(communes: [pulnoy], http: http, today: TODAY).call
    assert_equal :erreur, res.statut
  end

  test "un robots.txt qui interdit le flux est un refus" do
    http = FakeHttp.new(FLUX_PULNOY => Veille::Http::Refused.new("robots.txt de www.pulnoy.fr interdit /feed/"))
    res = Veille::Connectors::Communes.new(communes: [pulnoy], http: http, today: TODAY).call
    assert_equal :refuse, res.statut
  end

  test "par défaut ne lit que les communes automatisables" do
    http = FakeHttp.new
    Veille::Connectors::Communes.new(http: http, today: TODAY).call
    attendus = Veille::AnnuaireCommunes.automatisables.map(&:rss)
    assert_equal attendus.sort, http.appels.sort
    assert_equal 8, http.appels.size
    assert_no_match(/laxou|malzeville|saint-max/, http.appels.join, "pas de flux vide ni de commune sans flux")
  end

  test "dans le pipeline : candidats créés, doublon ignoré, passes automatiques non bloquées" do
    http = FakeHttp.new(FLUX_PULNOY => flux)
    items = Veille::Connectors::Communes.new(communes: [pulnoy], http: http, today: TODAY).call.items
    bilan = Veille::RawIngester.new(today: TODAY).ingest(items)
    assert_equal 1, bilan.crees.size
    assert_equal 1, Veille::RawIngester.new(today: TODAY).ingest(items).doublons

    cand = Veille::Candidate.find_by!(origin: "communes")
    assert_equal "Pulnoy", cand.commune
    assert_includes Veille::Candidate.a_enrichir, cand
    assert_equal "Sites des communes", Veille::Candidate.origine_label("communes")
  end

  test "est dans le quotidien, après l'agenda et Transentreprise" do
    assert_includes Veille::Runner::QUOTIDIEN, Veille::Connectors::Communes
    assert_equal "communes", Veille::Runner::PRIORITE.last
  end
end
