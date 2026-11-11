require "test_helper"
require_relative "../support"

class Veille::ConnectorsFluxPresseTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 11, 11)
  ICI_NORD = "https://www.ici.fr/rss/lorraine-nord/a-la-une.xml"
  ICI_SUD  = "https://www.ici.fr/rss/sud-lorraine/a-la-une.xml"
  F3       = "https://france3-regions.franceinfo.fr/grand-est/meurthe-et-moselle/nancy/rss"

  def fixture(nom) = File.read(Rails.root.join("test/fixtures/files/veille/#{nom}"))

  def lire(reponses)
    Veille::Connectors::FluxPresse.new(http: FakeHttp.new(reponses), today: TODAY).call
  end

  test "registre : les journaux dont les CGU s'opposent à la fouille de textes ne sont jamais lus" do
    lues = Veille::AnnuairePresse.automatisables.map(&:origine)
    assert_equal %w[france3_lorraine ici_lorraine], lues.sort
    ecartees = Veille::AnnuairePresse.ecartees.map(&:origine)
    assert_includes ecartees, "estrepublicain"
    assert_includes ecartees, "republicain_lorrain"
    assert_includes ecartees, "vosges_matin"
    assert_includes ecartees, "actu_nancy"
  end

  test "ICI Lorraine : titre, lien nettoyé, date et extrait ; lien étranger, ancien et sans titre écartés" do
    r = lire(ICI_NORD => fixture("presse_ici_flux.xml"), ICI_SUD => fixture("presse_ici_flux.xml"),
             F3 => fixture("presse_france3_flux.xml"))
    assert_equal :ok, r.statut
    ici = r.items.select { |i| i.origin == "ici_lorraine" }
    assert_equal 1, ici.size, "dédoublonné entre les deux flux ICI"
    i = ici.first
    assert_equal "https://www.ici.fr/vie-quotidienne/ferme-urbaine-nancy-1001", i.url
    assert_equal Date.new(2026, 11, 10), i.published_on
    assert_includes i.text, "Portrait d'une ancienne analyste"
    assert_includes i.text, "Source : ICI Lorraine"
    assert_nil i.type_hint, "le type est laissé à l'IA"
  end

  test "France 3 : les rubriques exclues (faits divers) n'entrent pas" do
    r = lire(ICI_NORD => fixture("presse_ici_flux.xml"), ICI_SUD => fixture("presse_ici_flux.xml"),
             F3 => fixture("presse_france3_flux.xml"))
    f3 = r.items.select { |i| i.origin == "france3_lorraine" }
    assert_equal ["Un atelier de réparation de vélos ouvre ses portes à Nancy"], f3.map(&:title)
  end

  test "un flux en panne n'empêche pas de lire les autres, et l'échec est dit" do
    r = lire(ICI_NORD => fixture("presse_ici_flux.xml"), ICI_SUD => Veille::Http::Error.new("HTTP 500"),
             F3 => fixture("presse_france3_flux.xml"))
    assert_equal :ok, r.statut
    assert_match "en échec", r.message
  end

  test "tous les flux en panne : statut erreur" do
    r = lire(ICI_NORD => Veille::Http::Error.new("x"), ICI_SUD => Veille::Http::Error.new("x"), F3 => Veille::Http::Error.new("x"))
    assert_equal :erreur, r.statut
  end

  test "l'extrait stocké est plafonné à 400 caractères" do
    long = fixture("presse_ici_flux.xml").sub("Portrait d'une ancienne analyste devenue maraîchère sur un toit de Nancy.", "mot " * 300)
    r = lire(ICI_NORD => long, ICI_SUD => long, F3 => fixture("presse_france3_flux.xml"))
    assert_operator r.items.find { |i| i.origin == "ici_lorraine" }.text.length, :<, 600
  end
end
