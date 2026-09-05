require "test_helper"

module Veille
  class SourceTest < ActiveSupport::TestCase
    def build(**attrs)
      Veille::Source.new({ name: "L'Est Républicain", kind: "presse", url: "https://estrepublicain.fr" }.merge(attrs))
    end

    test "la table est préfixée, sans collision avec la table sources existante" do
      assert_equal "veille_sources", Veille::Source.table_name
    end

    test "valide avec les attributs attendus" do
      assert build.valid?
    end

    test "exige nom, type et url" do
      %i[name kind url].each do |champ|
        source = build(champ => nil)
        assert_not source.valid?, "#{champ} devrait être obligatoire"
        assert_includes source.errors.attribute_names, champ
      end
    end

    test "le nom est unique" do
      build.save!
      doublon = build(url: "https://autre.fr")
      assert_not doublon.valid?
      assert_includes doublon.errors[:name], "has already been taken"
    end

    test "n'accepte que les trois types prévus" do
      assert_equal %w[presse magazine_municipal media_public], Veille::Source::KINDS
      Veille::Source::KINDS.each { |k| assert build(kind: k).valid?, "#{k} devrait être accepté" }

      hors_liste = build(kind: "rss")
      assert_not hors_liste.valid?, "les types de l'autre pipeline ne doivent pas passer"
    end

    test "active par défaut, et le scope actives filtre" do
      active   = build(name: "A").tap(&:save!)
      inactive = build(name: "B", url: "https://b.fr", active: false).tap(&:save!)

      assert active.active?
      assert_includes Veille::Source.actives, active
      assert_not_includes Veille::Source.actives, inactive
    end
  end
end
