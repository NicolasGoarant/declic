require "test_helper"

class OpportunityDatesTest < ActiveSupport::TestCase
  test "seul l'ISO strict AAAA-MM-JJ est une date" do
    assert_equal Date.new(2026, 10, 3), Opportunity.date_iso("2026-10-03")
    assert_equal Date.new(2026, 10, 3), Opportunity.date_iso(" 2026-10-03 ")
    assert_nil Opportunity.date_iso("Toute l'année")
    assert_nil Opportunity.date_iso("03/10/2026")
    assert_nil Opportunity.date_iso("2026-02-30")
    assert_nil Opportunity.date_iso("2026-10-03T10:00")
    assert_nil Opportunity.date_iso(nil)
  end

  test "date_debut et date_fin lisent start_date et end_date" do
    o = Opportunity.new(start_date: "2026-10-03", end_date: "Inscriptions jusqu'au 12")
    assert_equal Date.new(2026, 10, 3), o.date_debut
    assert_nil o.date_fin
  end

  test "date_debut préfère starts_on" do
    o = Opportunity.new(start_date: "2026-10-03", starts_on: Date.new(2026, 11, 1))
    assert_equal Date.new(2026, 11, 1), o.date_debut
  end

  # --- Pont before_save start_date / end_date -> starts_on / ends_on ---

  test "le pont recopie l'ISO saisi dans l'admin" do
    o = opportunities(:one)
    o.update_columns(starts_on: nil, ends_on: nil)
    o.start_date = "2026-02-14"
    o.end_date = "2026-02-15"
    o.save!(validate: false)
    assert_equal [ Date.new(2026, 2, 14), Date.new(2026, 2, 15) ], o.reload.values_at(:starts_on, :ends_on)
  end

  test "le pont vide la date quand la chaîne est vidée, et ignore le texte libre" do
    o = opportunities(:one)
    o.update_columns(start_date: "2026-02-14", starts_on: Date.new(2026, 2, 14),
                     end_date: "2026-02-15", ends_on: Date.new(2026, 2, 15))
    o.start_date = ""
    o.end_date = "Toute l'année"
    o.save!(validate: false)
    o.reload
    assert_nil o.starts_on
    assert_equal Date.new(2026, 2, 15), o.ends_on
  end

  test "le pont ne touche à rien si start_date ne change pas" do
    o = opportunities(:one)
    o.update_columns(start_date: "2026-02-14", starts_on: Date.new(2026, 3, 1))
    o.title = "Autre titre"
    o.save!(validate: false)
    assert_equal Date.new(2026, 3, 1), o.reload.starts_on
  end

  # --- Méthodes d'affichage ---

  test "date_affichee" do
    assert_equal "Sam. 14 février 2026", Opportunity.new(starts_on: Date.new(2026, 2, 14)).date_affichee
    assert_equal "Sam. 14 février 2026",
                 Opportunity.new(starts_on: Date.new(2026, 2, 14), ends_on: Date.new(2026, 2, 14)).date_affichee
    assert_equal "Du sam. 14 février au dim. 15 mars 2026",
                 Opportunity.new(starts_on: Date.new(2026, 2, 14), ends_on: Date.new(2026, 3, 15)).date_affichee
    assert_equal "Du jeu. 31 décembre 2026 au ven. 1 janvier 2027",
                 Opportunity.new(starts_on: Date.new(2026, 12, 31), ends_on: Date.new(2027, 1, 1)).date_affichee
    assert_equal "Jusqu'au mar. 30 juin 2026", Opportunity.new(ends_on: Date.new(2026, 6, 30)).date_affichee
    assert_nil Opportunity.new.date_affichee
  end

  test "horaire_affiche" do
    assert_equal "14h - 18h", Opportunity.new(start_time: "14:00", end_time: "18:00").horaire_affiche
    assert_equal "9h30", Opportunity.new(start_time: "09:30").horaire_affiche
    assert_equal "Ouvert toute l'année, sur rendez-vous",
                 Opportunity.new(schedule_text: "Ouvert toute l'année, sur rendez-vous").horaire_affiche
    assert_nil Opportunity.new.horaire_affiche
  end

  test "permanente, à venir, passée" do
    travel_to Time.utc(2026, 9, 26, 12) do
      permanente = Opportunity.new
      assert permanente.permanente?
      assert_not permanente.a_venir?
      assert_not permanente.passee?

      en_cours = Opportunity.new(starts_on: Date.new(2026, 9, 20), ends_on: Date.new(2026, 9, 26))
      assert en_cours.a_venir?
      assert_not en_cours.passee?

      assert Opportunity.new(starts_on: Date.new(2026, 9, 25)).passee?
      assert Opportunity.new(starts_on: Date.new(2026, 10, 1)).a_venir?
    end
  end

  test "le jour s'apprécie à l'heure de Paris" do
    # 23h30 UTC le 25 = 1h30 le 26 à Paris : une opportunité du 25 est passée.
    travel_to Time.utc(2026, 9, 25, 23, 30) do
      assert Opportunity.new(starts_on: Date.new(2026, 9, 25)).passee?
    end
  end

  test "programme_liste écarte les étapes vides" do
    o = Opportunity.new(programme: [ "Diagnostic de votre objet", " ", "Atelier accompagné" ])
    assert_equal [ "Diagnostic de votre objet", "Atelier accompagné" ], o.programme_liste
  end
end
