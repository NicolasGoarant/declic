require "test_helper"

module Veille
  class CandidateTest < ActiveSupport::TestCase
    def build(**attrs)
      Veille::Candidate.new({ url: "https://exemple.fr/article-1", title: "Un titre" }.merge(attrs))
    end

    test "la table est préfixée" do
      assert_equal "veille_candidates", Veille::Candidate.table_name
    end

    test "naît en attente, sans catégorie ni score" do
      c = build
      assert c.valid?
      assert_equal "pending", c.status
      assert_nil c.category
      assert_nil c.score
      assert_not c.qualified?
    end

    test "l'url est obligatoire et unique" do
      build.save!
      doublon = build
      assert_not doublon.valid?
      assert_includes doublon.errors[:url], "has already been taken"

      assert_not build(url: nil).valid?
    end

    test "le score reste borné entre 0 et 100, et accepte nil" do
      assert build(score: nil).valid?
      assert build(score: 0).valid?
      assert build(score: 100).valid?
      assert_not build(score: -1).valid?
      assert_not build(score: 101).valid?
    end

    test "n'accepte que les catégories et statuts prévus" do
      assert_equal %w[belle_histoire autre], Veille::Candidate::CATEGORIES
      assert_equal %w[pending a_verifier retenu ecarte publie], Veille::Candidate::STATUSES

      assert_not build(category: "faits_divers").valid?
      assert_not build(status: "brouillon").valid?
    end

    test "la source est facultative" do
      assert build(source: nil).valid?

      source = Veille::Source.create!(name: "Mag municipal", kind: "magazine_municipal", url: "https://nancy.fr")
      c = build(source: source)
      assert c.valid?
      assert_equal source, c.source
      assert_includes source.candidates, c.tap(&:save!)
    end

    test "supprimer la source détache les candidats sans les détruire" do
      source = Veille::Source.create!(name: "À supprimer", kind: "presse", url: "https://x.fr")
      c = build(source: source)
      c.save!

      source.destroy
      assert Veille::Candidate.exists?(c.id), "le candidat doit survivre"
      assert_nil c.reload.veille_source_id
    end

    test "file_de_tri ne rend que les pending, meilleur score d'abord" do
      faible  = build(url: "https://e.fr/1", score: 20).tap(&:save!)
      fort    = build(url: "https://e.fr/2", score: 95).tap(&:save!)
      moyen   = build(url: "https://e.fr/3", score: 60).tap(&:save!)
      retenu  = build(url: "https://e.fr/4", score: 99, status: "retenu").tap(&:save!)
      sans    = build(url: "https://e.fr/5", score: nil).tap(&:save!)

      file = Veille::Candidate.file_de_tri.to_a
      assert_not_includes file, retenu, "la file ne montre que les candidats en attente"
      assert_equal [fort, moyen, faible], file.first(3)
      assert_equal sans, file.last, "les non qualifiés passent en dernier"
    end

    test "source_label retombe sur l'hôte quand aucune source n'est rattachée" do
      assert_equal "estrepublicain.fr", build(url: "https://www.estrepublicain.fr/a/b").source_label

      source = Veille::Source.create!(name: "Est Rép", kind: "presse", url: "https://estrepublicain.fr")
      assert_equal "Est Rép", build(source: source).source_label
    end

    test "host tolère une url malformée" do
      assert_nil build(url: "pas une url").host
    end
  end
end
