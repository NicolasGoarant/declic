require "test_helper"
require_relative "support"

class Veille::RawIngesterTest < ActiveSupport::TestCase
  include VeilleSupport

  setup { @ing = Veille::RawIngester.new(today: Date.new(2026, 10, 13), now: Time.zone.local(2026, 10, 13, 6)) }

  test "stocke source, URL, date de collecte et texte récupéré" do
    bilan = @ing.ingest([item(url: "https://exemple.fr/a", title: "Atelier", text: "Texte brut.", starts_on: Date.new(2026, 11, 3))])
    c = bilan.crees.first

    assert_equal "agenda_nancy", c.origin
    assert_equal "https://exemple.fr/a", c.url
    assert_equal Time.zone.local(2026, 10, 13, 6), c.fetched_at
    assert_equal "Texte brut.", c.full_text
    assert_equal "pending", c.status
  end

  test "dédoublonne par URL, puis par titre normalisé et date" do
    @ing.ingest([item(url: "https://exemple.fr/a", title: "Atelier vélo", starts_on: Date.new(2026, 11, 3))])
    bilan = @ing.ingest([
      item(url: "https://exemple.fr/a", title: "Autre"),
      item(url: "https://exemple.fr/b", title: "ATELIER  vélo !", starts_on: Date.new(2026, 11, 3)),
      item(url: "https://exemple.fr/c", title: "Atelier vélo", starts_on: Date.new(2026, 11, 4))
    ])

    assert_equal 2, bilan.doublons
    assert_equal 1, bilan.crees.size
  end

  test "écarte d'emblée le hors Grand Nancy et le passé, sans les stocker" do
    bilan = @ing.ingest([
      item(commune: "Toul", title: "Loin"),
      item(commune: "Nancy", title: "Hier", starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 10, 2)),
      item(commune: "Nancy", title: "En cours", starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 11, 2))
    ])

    assert_equal 1, bilan.hors_zone
    assert_equal 1, bilan.passes
    assert_equal ["En cours"], bilan.crees.map(&:title)
  end

  test "une commune absente n'écarte pas l'élément : l'enrichissement tranchera" do
    assert_equal 1, @ing.ingest([item(commune: nil)]).crees.size
  end
end
