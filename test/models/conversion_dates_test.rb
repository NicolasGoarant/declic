require "test_helper"

class ConversionDatesTest < ActiveSupport::TestCase
  def opportunite(**attributs) = Opportunity.new(**attributs)
  def conversion(**attributs) = ConversionDates.new(opportunite(**attributs))

  test "les chaînes ISO deviennent starts_on / ends_on" do
    c = conversion(start_date: "2026-02-14", end_date: " 2026-02-15 ")
    assert_equal({ starts_on: Date.new(2026, 2, 14), ends_on: Date.new(2026, 2, 15) }, c.changements)
    assert_equal Set[:iso], c.cas
  end

  test "une date déjà présente dans starts_on n'est pas réécrite" do
    c = conversion(start_date: "2026-02-14", starts_on: Date.new(2026, 1, 1))
    assert_not c.changements.key?(:starts_on)
    assert_includes c.cas, :iso
  end

  test "le texte libre va dans schedule_text vide, et l'opportunité reste permanente" do
    c = conversion(start_date: "Toute l'année")
    assert_equal({ schedule_text: "Toute l'année" }, c.changements)
    assert_equal Set[:texte_bascule, :permanente], c.cas
  end

  test "le texte libre est conservé et compté quand schedule_text est déjà rempli" do
    c = conversion(start_date: "Inscriptions jusqu'au 12", schedule_text: "Le mardi soir")
    assert_empty c.changements
    assert_includes c.cas, :texte_conserve
  end

  test "deux textes libres différents : le premier bascule, le second est conservé" do
    c = conversion(start_date: "Printemps", end_date: "Été")
    assert_equal "Printemps", c.changements[:schedule_text]
    assert_includes c.cas, :texte_bascule
    assert_includes c.cas, :texte_conserve
  end

  test "un texte déjà basculé compte comme basculé quand on relance le rapport" do
    c = conversion(start_date: "Toute l'année", schedule_text: "Toute l'année")
    assert_empty c.changements
    assert_includes c.cas, :texte_bascule
    assert_not_includes c.cas, :texte_conserve
  end

  test "starts_at / ends_at remplissent date et heure de Paris quand starts_on est vide" do
    c = conversion(starts_at: Time.utc(2026, 6, 25, 17), ends_at: Time.utc(2026, 1, 10, 22, 30))
    assert_equal Date.new(2026, 6, 25), c.changements[:starts_on]
    assert_equal "19:00", c.changements[:start_time] # heure d'été : UTC+2
    assert_equal Date.new(2026, 1, 10), c.changements[:ends_on]
    assert_equal "23:30", c.changements[:end_time]   # heure d'hiver : UTC+1
    assert_equal Set[:reconcilie], c.cas
  end

  test "l'heure de Paris peut changer le jour" do
    c = conversion(starts_at: Time.utc(2026, 6, 25, 22, 30))
    assert_equal Date.new(2026, 6, 26), c.changements[:starts_on]
    assert_equal "00:30", c.changements[:start_time]
  end

  test "minuit UTC pile est une date sans heure" do
    c = conversion(starts_at: Time.utc(2026, 3, 22))
    assert_equal Date.new(2026, 3, 22), c.changements[:starts_on]
    assert_not c.changements.key?(:start_time)
  end

  test "starts_at est ignoré quand start_date ISO a déjà donné starts_on" do
    c = conversion(start_date: "2026-09-26", starts_at: Time.utc(2025, 12, 10, 14))
    assert_equal Date.new(2026, 9, 26), c.changements[:starts_on]
    assert_not c.changements.key?(:start_time)
    assert_not_includes c.cas, :reconcilie
  end

  test "sans aucune date l'opportunité est permanente" do
    assert_equal Set[:permanente], conversion.cas
  end

  test "la migration de données écrit les conversions en base" do
    require Rails.root.join("db/migrate/20260926090200_reprend_dates_des_opportunites")
    iso = opportunities(:one)
    iso.update_columns(start_date: "2026-02-14", end_date: "2026-02-14", schedule_text: nil)
    libre = opportunities(:two)
    libre.update_columns(start_date: "Ouvert toute l'année", end_date: nil, schedule_text: nil,
                         starts_at: nil, ends_at: nil)

    ActiveRecord::Migration.suppress_messages { ReprendDatesDesOpportunites.new.up }

    assert_equal [ Date.new(2026, 2, 14) ] * 2, iso.reload.values_at(:starts_on, :ends_on)
    assert_nil libre.reload.starts_on
    assert_equal "Ouvert toute l'année", libre.schedule_text
    assert_equal "Ouvert toute l'année", libre.start_date # l'ancienne colonne reste intacte
  end
end
