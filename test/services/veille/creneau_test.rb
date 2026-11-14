require "test_helper"

class Veille::CreneauTest < ActiveSupport::TestCase
  def t(h, m = 0) = Time.utc(2000, 1, 1, h, m)
  def d(*a) = Date.new(*a)

  test "un jour" do
    assert_equal "Sam. 28 nov. 2026", Veille::Creneau.pour(debut: d(2026, 11, 28)).date
    assert_equal "Sam. 28 nov. 2026", Veille::Creneau.pour(debut: d(2026, 11, 28), fin: d(2026, 11, 28)).date
  end

  test "un jour avec l'heure" do
    assert_equal "Dim. 13 déc. 2026 · 14h30", Veille::Creneau.pour(debut: d(2026, 12, 13), heure_debut: t(14, 30)).date
    assert_equal "Sam. 28 nov. 2026 · 11h-12h", Veille::Creneau.pour(debut: d(2026, 11, 28), heure_debut: t(11), heure_fin: t(12)).date
  end

  test "le premier du mois s'écrit 1er" do
    assert_equal "Dim. 1er nov. 2026", Veille::Creneau.pour(debut: d(2026, 11, 1)).date
  end

  test "quelques jours dans le même mois" do
    assert_equal "Du 27 au 29 nov. 2026", Veille::Creneau.pour(debut: d(2026, 11, 27), fin: d(2026, 11, 29)).date
  end

  test "à cheval sur deux mois, même année" do
    assert_equal "Du 28 nov. au 13 déc. 2026", Veille::Creneau.pour(debut: d(2026, 11, 28), fin: d(2026, 12, 13)).date
  end

  test "créneau long sur deux années, avec périodicité et horaires sur la ligne suivante" do
    c = Veille::Creneau.pour(debut: d(2026, 10, 10), fin: d(2027, 3, 28), periodicite: "tous les samedis et dimanches",
                             heure_debut: t(11), heure_fin: t(12))
    assert_equal "Du 10 oct. 2026 au 28 mars 2027", c.date
    assert_equal "tous les samedis et dimanches, 11h-12h", c.periodicite
  end

  test "horaires déjà dits dans la périodicité : pas répétés" do
    c = Veille::Creneau.pour(debut: d(2026, 10, 10), fin: d(2027, 3, 28), periodicite: "samedis de 11h à 12h", heure_debut: t(11), heure_fin: t(12))
    assert_equal "samedis de 11h à 12h", c.periodicite
  end

  test "fin seule : Jusqu'au" do
    assert_equal "Jusqu'au 28 mars 2027", Veille::Creneau.pour(fin: d(2027, 3, 28)).date
  end

  test "offre permanente : sans date limite, ou toute l'année" do
    assert_equal "Sans date limite", Veille::Creneau.pour.date
    perm = Veille::Creneau.pour(periodicite: "Sur rendez-vous")
    assert_equal ["Sans date limite", "Sur rendez-vous"], [perm.date, perm.periodicite]
    annee = Veille::Creneau.pour(periodicite: "Ouvert toute l'année")
    assert_equal "Toute l'année", annee.date
    assert_nil annee.periodicite
  end
end
