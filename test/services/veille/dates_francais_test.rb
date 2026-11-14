require "test_helper"

class Veille::DatesFrancaisTest < ActiveSupport::TestCase
  REF = Date.new(2026, 10, 13)

  def lire(texte) = Veille::DatesFrancais.analyser(texte, reference: REF)
  def h(h, m = 0) = Time.utc(2000, 1, 1, h, m)

  test "Chefs-d'œuvre de l'École de Nancy : fin, heures et périodicité" do
    r = lire("Jusqu'au 28 mars 2027, tous les samedis et dimanches de 11h à 12h. Sur réservation")
    assert_nil r.starts_on
    assert_equal Date.new(2027, 3, 28), r.ends_on
    assert_equal [h(11), h(12)], [r.start_time, r.end_time]
    assert_equal "tous les samedis et dimanches", r.periodicite
  end

  test "un jour avec jour de semaine, année déduite" do
    r = lire("Visite guidée. Dimanche 13 décembre. Sur réservation")
    assert_equal Date.new(2026, 12, 13), r.starts_on
    assert_nil r.ends_on
  end

  test "année suivante si le jour est passé à la date de référence" do
    assert_equal Date.new(2027, 1, 5), lire("le 5 janvier").starts_on
  end

  test "plage avec jours de semaine" do
    r = lire("Du samedi 27 au dimanche 29 novembre")
    assert_equal [Date.new(2026, 11, 27), Date.new(2026, 11, 29)], [r.starts_on, r.ends_on]
  end

  test "plage sur deux mois, et « les 16 et 17 octobre 2026 »" do
    r = lire("Du 30 novembre au 3 décembre")
    assert_equal [Date.new(2026, 11, 30), Date.new(2026, 12, 3)], [r.starts_on, r.ends_on]
    r = lire("Les 16 et 17 octobre 2026")
    assert_equal [Date.new(2026, 10, 16), Date.new(2026, 10, 17)], [r.starts_on, r.ends_on]
  end

  test "heure seule, sans date" do
    r = lire("Aujourd'hui à 18h")
    assert_nil r.starts_on
    assert_equal [h(18), nil], [r.start_time, r.end_time]
    assert_equal h(14, 30), lire("à 14h30").start_time
  end

  test "périodicité « du mardi au samedi »" do
    assert_equal "du mardi au samedi", lire("Ouvert du mardi au samedi, 10h-18h").periodicite
    assert_equal [h(10), h(18)], lire("Ouvert du mardi au samedi, 10h-18h").then { |r| [r.start_time, r.end_time] }
  end

  test "rien de daté : résultat vide ; date inexistante ignorée" do
    assert lire("Un joli texte sans date.").vide?
    assert_nil lire("le 31 novembre").starts_on
  end
end
