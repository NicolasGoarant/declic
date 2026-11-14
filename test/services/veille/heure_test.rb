require "test_helper"

class Veille::HeureTest < ActiveSupport::TestCase
  def t(h, m = 0) = Time.utc(2000, 1, 1, h, m)

  test "lit chaque format de chaîne" do
    { "14:00" => t(14), "14h" => t(14), "14h30" => t(14, 30), "9h00" => t(9), "9 h 05" => t(9, 5), "09:30" => t(9, 30), "14:00:00" => nil }.each do |texte, attendu|
      next if attendu.nil? # secondes : lues par la colonne, pas ici

      assert_equal attendu, Veille::Heure.lire(texte), texte
    end
  end

  test "accepte un Time, nil et le vide" do
    assert_equal t(11, 15), Veille::Heure.lire(Time.utc(2026, 5, 3, 11, 15))
    assert_nil Veille::Heure.lire(nil)
    assert_nil Veille::Heure.lire("  ")
  end

  test "ignore une valeur illisible en la journalisant" do
    sortie = StringIO.new
    ancien, Rails.logger = Rails.logger, ActiveSupport::Logger.new(sortie)
    assert_nil Veille::Heure.lire("bientôt")
    assert_nil Veille::Heure.lire("25h00")
    assert_match(/heure illisible ignorée/, sortie.string)
  ensure
    Rails.logger = ancien
  end

  test "affiche 14h ou 14h30" do
    assert_equal "14h", Veille::Heure.afficher("14:00")
    assert_equal "14h30", Veille::Heure.afficher("14h30")
    assert_nil Veille::Heure.afficher(nil)
  end

  test "le candidat enregistre toujours un Time, quelle que soit la forme reçue" do
    c = Veille::Candidate.create!(url: "https://exemple.fr/h", title: "H", origin: "agenda_nancy", full_text: "T", start_time: "14h30", end_time: "16:00")
    c.reload
    assert_equal [ 14, 30 ], [ c.start_time.hour, c.start_time.min ]
    assert_equal [ 16, 0 ], [ c.end_time.hour, c.end_time.min ]
    c.update!(start_time: "n'importe quoi")
    assert_nil c.reload.start_time
  end
end
