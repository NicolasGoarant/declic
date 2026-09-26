require "test_helper"

class FicheAdminTest < ActiveSupport::TestCase
  def opportunite(**attributs)
    Opportunity.new({ title: "Repair Café", description: "Texte", category: "ecologiser" }.merge(attributs))
  end

  # --- Pont inverse starts_on / ends_on -> start_date / end_date ---

  test "le pont inverse écrit les chaînes ISO depuis starts_on et ends_on" do
    o = opportunite(starts_on: Date.new(2026, 2, 14), ends_on: Date.new(2026, 2, 15))
    o.save!
    assert_equal "2026-02-14", o.start_date
    assert_equal "2026-02-15", o.end_date
  end

  test "le pont inverse vide la chaîne quand la date est effacée" do
    o = opportunite(starts_on: Date.new(2026, 2, 14))
    o.save!
    o.update!(starts_on: nil)
    assert_nil o.reload.start_date
  end

  test "le pont inverse remplace un texte libre seulement quand starts_on change" do
    o = opportunite(start_date: "Toute l'année")
    o.save!
    o.update!(title: "Autre titre")
    assert_equal "Toute l'année", o.reload.start_date
    o.update!(starts_on: Date.new(2026, 5, 1))
    assert_equal "2026-05-01", o.reload.start_date
  end

  test "si les deux changent, la colonne date l'emporte" do
    o = opportunite(start_date: "2026-01-01", starts_on: Date.new(2026, 3, 3))
    o.save!
    assert_equal "2026-03-03", o.start_date
    assert_equal Date.new(2026, 3, 3), o.starts_on
  end

  # --- Programme : textarea <-> tableau ---

  test "programme_texte : une étape par ligne, lignes vides écartées" do
    o = opportunite(programme_texte: "Diagnostic \r\n\r\n  Atelier accompagné\nConseils\n")
    assert_equal [ "Diagnostic", "Atelier accompagné", "Conseils" ], o.programme
    assert_equal "Diagnostic\nAtelier accompagné\nConseils", o.programme_texte
    o.save!
    assert_equal [ "Diagnostic", "Atelier accompagné", "Conseils" ], o.reload.programme
  end

  # --- Points forts : trois blocs fixes ---

  test "points_forts_saisie ignore les blocs vides et garde l'ordre" do
    s = Story.new(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18)
    s.points_forts_saisie = {
      "0" => { "icone" => "coeur", "titre" => "Un titre", "texte" => "" },
      "1" => { "icone" => "goutte", "titre" => "", "texte" => "" },
      "2" => { "icone" => "", "titre" => "", "texte" => "Un texte seul" }
    }
    assert_equal [ { "icone" => "coeur", "titre" => "Un titre", "texte" => "" },
                   { "icone" => "", "titre" => "", "texte" => "Un texte seul" } ], s.points_forts
    assert s.valid?, s.errors.full_messages.to_sentence
  end

  test "points_forts_saisie propose toujours trois blocs et rejette une icône inconnue" do
    s = Story.new
    assert_equal 3, s.points_forts_saisie.size
    s.points_forts_saisie = { "0" => { "icone" => "inconnue", "titre" => "T" } }
    assert_equal "", s.points_forts.first["icone"]
  end

  test "la localisation est exigée à la création seulement" do
    assert_not Story.new(title: "T").valid?
    ancienne = stories(:one)
    ancienne.update_columns(location: nil)
    ancienne.reload.valid?
    assert_empty ancienne.errors[:location]
  end

  # --- Complétude ---

  test "complétude d'une opportunité" do
    assert_equal 0, opportunite(description: nil).completude
    complete = opportunite(image_url: "https://x/y.jpg", starts_on: Date.new(2026, 1, 1), address: "1 rue A",
                           programme: [ "a" ], audience: "Tous", cta_button_text: "Je m'inscris",
                           cta_button_url: "https://x")
    assert_equal 100, complete.completude
    assert_equal [ "bouton" ], complete.tap { |o| o.cta_button_url = nil }.champs_manquants
    assert_equal 86, complete.completude # 6 critères sur 7
  end

  test "complétude d'une histoire" do
    s = Story.new(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, quote: "Une citation")
    assert_equal 40, s.completude
    s.assign_attributes(image_url: "https://x/y.jpg", source_name: "Média", source_url: "https://x",
                        points_forts: [ { "texte" => "a" } ])
    assert_equal 100, s.completude
  end

  # --- Galerie ---

  def png(nom = "pixel.png") = Rack::Test::UploadedFile.new(file_fixture(nom), "image/png")

  test "la galerie ajoute, réordonne et supprime, la couverture est la première" do
    o = opportunite
    o.save!
    o.appliquer_galerie(nouvelles: [ png, png, png ])
    a, b, c = o.photos_ordonnees.map(&:id)
    assert_equal a, o.couverture.id

    o.appliquer_galerie(positions: { c => "1", a => "2", b => "3" })
    assert_equal [ c, a, b ], o.reload.photos_ordonnees.map(&:id)

    o.appliquer_galerie(supprimer: [ c ], nouvelles: [ png ])
    ids = o.reload.photos_ordonnees.map(&:id)
    assert_equal [ a, b ], ids.first(2)
    assert_equal 3, ids.size
    assert_equal a, o.couverture.id
  end

  test "sans photos, la couverture est l'ancienne image principale" do
    o = opportunite
    o.save!
    assert_nil o.couverture
    o.image.attach(png)
    assert_equal o.image.attachment, o.couverture
    assert o.a_une_photo?
  end
end
