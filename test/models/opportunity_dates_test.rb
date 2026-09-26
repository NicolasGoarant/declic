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
end
