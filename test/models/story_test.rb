require "test_helper"

class StoryTest < ActiveSupport::TestCase
  def candidat(**attrs)
    Veille::Candidate.create!({
      url:       "https://exemple.fr/article-#{SecureRandom.hex(4)}",
      title:     "Un titre",
      full_text: "Le texte intégral de l'article de presse, mot pour mot.",
      status:    "retenu"
    }.merge(attrs))
  end

  # ------------------------------------------------------------------
  # La règle centrale du chantier.
  # ------------------------------------------------------------------
  test "créer la fiche efface full_text du candidat" do
    c = candidat
    assert c.full_text?, "préalable : le tampon est rempli"

    Story.create!(title: "Une belle histoire", veille_candidate: c)

    assert_nil c.reload.full_text,
               "full_text est un tampon de travail : Déclic ne constitue pas " \
               "de base dérivée d'articles de presse"
    assert_not c.full_text?
  end

  test "la purge conserve tout le reste du candidat" do
    c = candidat(excerpt: "Le chapeau", score: 88, category: "belle_histoire", reason: "Motif")
    url_avant = c.url

    Story.create!(title: "T", veille_candidate: c)
    c.reload

    assert_equal "Le chapeau", c.excerpt
    assert_equal 88, c.score
    assert_equal "belle_histoire", c.category
    assert_equal "Motif", c.reason
    assert_equal url_avant, c.url, "le lien vers la source est ce qu'on garde"
  end

  test "la purge n'écrase pas une fiche sans candidat" do
    assert_nothing_raised { Story.create!(title: "Histoire saisie à la main") }
  end

  test "la purge est sans effet si le tampon est déjà vide" do
    c = candidat(full_text: nil)
    story = Story.create!(title: "T", veille_candidate: c)

    assert_nil c.reload.full_text
    assert_equal c, story.veille_candidate
  end

  test "le lien candidat vers fiche fonctionne dans les deux sens" do
    c = candidat
    story = Story.create!(title: "T", veille_candidate: c)

    assert_equal story, c.reload.story
    assert_equal c, story.veille_candidate
  end

  test "supprimer le candidat ne détruit pas la fiche publiée" do
    c = candidat
    story = Story.create!(title: "T", veille_candidate: c)

    c.destroy
    assert Story.exists?(story.id), "une histoire publiée survit à son candidat"
    assert_nil story.reload.veille_candidate_id
  end

  test "la fiche issue de la veille naît inactive" do
    story = Story.create!(title: "T", veille_candidate: candidat)
    assert_not story.is_active, "elle est relue en admin avant publication"
  end
end
