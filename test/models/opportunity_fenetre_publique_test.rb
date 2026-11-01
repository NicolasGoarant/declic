require "test_helper"

# Petites manifestations (brocante, vide-grenier…) : visibles du 7e jour avant le début jusqu'au dernier jour inclus.
class OpportunityFenetrePubliqueTest < ActiveSupport::TestCase
  AUJOURDHUI = Date.new(2026, 11, 10)

  # Instant à Paris : midi par défaut, pour les cas qui ne jouent pas sur l'heure.
  def a(jour, heure = "12:00:00") = ActiveSupport::TimeZone[ConversionDates::FUSEAU].parse("#{jour} #{heure}")

  def fiche(famille: "petite_manifestation", debut: nil, fin: nil)
    Opportunity.create!(title: "Fiche #{SecureRandom.hex(3)}", description: "Texte.", category: "decouvrir",
                        latitude: 48.69, longitude: 6.18, famille: famille, starts_on: debut, ends_on: fin, is_active: true)
  end

  def publiques(instant = a(AUJOURDHUI)) = Opportunity.publiques(instant)

  test "avant la fenêtre (début dans 8 jours) : invisible en public, visible dans l'admin" do
    o = fiche(debut: AUJOURDHUI + 8)
    assert_not_includes publiques, o
    assert_not o.dans_la_fenetre_publique?(a(AUJOURDHUI))
    assert_includes Opportunity.where(is_active: true), o
  end

  test "pendant la fenêtre : visible dès 7 jours avant, le jour même et le dernier jour d'une plage" do
    assert_includes publiques, fiche(debut: AUJOURDHUI + 7)
    assert_includes publiques, fiche(debut: AUJOURDHUI)
    en_cours = fiche(debut: AUJOURDHUI - 1, fin: AUJOURDHUI)
    assert_includes publiques, en_cours
    assert en_cours.dans_la_fenetre_publique?(a(AUJOURDHUI))
  end

  test "après la fenêtre (fini hier) : invisible en public, toujours en base et dans l'admin" do
    unique = fiche(debut: AUJOURDHUI - 1)
    plage  = fiche(debut: AUJOURDHUI - 3, fin: AUJOURDHUI - 1)
    [unique, plage].each do |o|
      assert_not_includes publiques, o
      assert_not o.dans_la_fenetre_publique?(a(AUJOURDHUI))
      assert_includes Opportunity.where(is_active: true), o
    end
  end

  test "sans date de fin, la date de début sert de fin" do
    o = fiche(debut: AUJOURDHUI)
    assert_includes publiques(a(AUJOURDHUI)), o
    assert_not_includes publiques(a(AUJOURDHUI + 1)), o
  end

  test "les autres familles ne sont pas concernées, ni une petite manifestation sans date" do
    lointaine = fiche(famille: "pratiquer", debut: AUJOURDHUI + 60)
    passee    = fiche(famille: "decouvrir", debut: AUJOURDHUI - 30)
    sans_famille = fiche(famille: nil, debut: AUJOURDHUI + 60)
    sans_date = fiche
    [lointaine, passee, sans_famille, sans_date].each { |o| assert_includes publiques, o }
  end

  test "une fiche inactive reste hors du public" do
    o = fiche(debut: AUJOURDHUI)
    o.update_columns(is_active: false)
    assert_not_includes publiques, o
  end

  test "cas limite : la fiche tient jusqu'au lendemain 00h00:59 et disparaît à 00h01" do
    o = fiche(debut: AUJOURDHUI, fin: AUJOURDHUI + 1)
    lendemain = AUJOURDHUI + 2
    assert_includes publiques(a(AUJOURDHUI + 1, "23:59:59")), o
    assert_includes publiques(a(lendemain, "00:00:00")), o
    assert_includes publiques(a(lendemain, "00:00:59")), o
    assert_not_includes publiques(a(lendemain, "00:01:00")), o
    assert_not o.dans_la_fenetre_publique?(a(lendemain, "00:01:00"))
    assert o.dans_la_fenetre_publique?(a(lendemain, "00:00:59"))
  end

  test "le début ne bouge pas : 00h00 sept jours avant, pas avant" do
    o = fiche(debut: AUJOURDHUI + 7)
    assert_not_includes publiques(a(AUJOURDHUI - 1, "23:59:59")), o
    assert_includes publiques(a(AUJOURDHUI, "00:00:00")), o
    assert_includes publiques(a(AUJOURDHUI, "00:01:00")), o
  end
end
