require "test_helper"

class Taxonomie::RecategorisationTest < ActiveSupport::TestCase
  def ancienne_fiche(titre, famille: nil)
    fiche = Opportunity.create!(title: titre, description: "Texte.", category: "pratiquer", is_active: true, famille: famille)
    fiche.update_columns(category: "rencontres")
    fiche
  end

  test "le fichier relu ne vise que des catégories valides et garde les familles masquées en Découvrir" do
    decisions = JSON.parse(Taxonomie::Recategorisation::FICHIER.read)
    assert_equal decisions.size, decisions.map { |d| d["id"] }.uniq.size
    assert_empty decisions.map { |d| d["vers"] } - Opportunity::CATEGORIES
    masquees = decisions.select { |d| Opportunity::FAMILLES_MASQUEES.include?(d["famille"]) }
    assert masquees.any?
    assert_equal [ "decouvrir" ], masquees.map { |d| d["vers"] }.uniq
  end

  test "décision relue d'abord ; sinon la famille ; sans famille, le repli" do
    relue = ancienne_fiche("Galerie")
    par_famille = ancienne_fiche("Atelier", famille: "pratiquer")
    sans_rien = ancienne_fiche("Inconnue")
    autre_titre = ancienne_fiche("Pas le même titre", famille: "pratiquer")
    decisions = [ { "id" => relue.id, "titre" => "Galerie", "vers" => "benevolat" },
                  { "id" => autre_titre.id, "titre" => "Une autre fiche", "vers" => "benevolat" } ]

    Taxonomie::Recategorisation.new(decisions: decisions).appliquer

    assert_equal "benevolat", relue.reload.category
    assert_equal "pratiquer", par_famille.reload.category
    assert_equal "decouvrir", sans_rien.reload.category
    assert_equal "pratiquer", autre_titre.reload.category, "un identifiant dont le titre diffère n'est pas la fiche relue"
    assert_equal 0, Opportunity.where(category: "rencontres").count
  end

  test "sans appliquer, rien n'est écrit, et l'horodatage d'une fiche ne bouge pas au passage" do
    fiche = ancienne_fiche("Visite", famille: "decouvrir")
    fiche.update_columns(updated_at: 3.days.ago)
    avant = fiche.reload.updated_at
    passage = Taxonomie::Recategorisation.new(decisions: [])

    assert_equal [ "decouvrir" ], passage.changements.map(&:vers)
    assert_equal "rencontres", fiche.reload.category

    passage.appliquer
    assert_equal "decouvrir", fiche.reload.category
    assert_equal avant, fiche.updated_at
  end

  test "un candidat publié suit sa fiche, les autres leur famille" do
    fiche = ancienne_fiche("Galerie")
    publie = Veille::Candidate.create!(title: "Galerie", origin: "agenda_nancy", url: "https://exemple.test/#{SecureRandom.hex(4)}", item_type: "opportunite", famille: "decouvrir", status: "publie", opportunity: fiche)
    attente = Veille::Candidate.create!(title: "Atelier", origin: "agenda_nancy", url: "https://exemple.test/#{SecureRandom.hex(4)}", item_type: "opportunite", famille: "pratiquer", status: "pending")
    sans_famille = Veille::Candidate.create!(title: "Rien", origin: "agenda_nancy", url: "https://exemple.test/#{SecureRandom.hex(4)}", item_type: "opportunite", status: "pending")
    [ publie, attente, sans_famille ].each { |c| c.update_columns(declic_category: "rencontres") }

    Taxonomie::Recategorisation.new(decisions: [ { "id" => fiche.id, "titre" => "Galerie", "vers" => "benevolat" } ]).appliquer

    assert_equal "benevolat", publie.reload.declic_category
    assert_equal "pratiquer", attente.reload.declic_category
    assert_equal "decouvrir", sans_famille.reload.declic_category
    assert attente.valid?
  end
end
