require "test_helper"

# Une fiche issue de la veille raconte une personne réelle : pas de mise en ligne sans son accord.
class StoryAccordTest < ActiveSupport::TestCase
  setup do
    @candidat = Veille::Candidate.create!(url: "https://exemple.fr/#{SecureRandom.hex(3)}", title: "Un portrait")
  end

  def histoire(**attrs)
    Story.create!({ title: "Un portrait", location: "Nancy", latitude: 48.69, longitude: 6.18,
                    veille_candidate: @candidat }.merge(attrs))
  end

  test "une fiche de la veille ne peut pas être mise en ligne sans accord" do
    s = histoire
    assert_not s.update(is_active: true)
    assert_includes s.errors.full_messages.to_sentence, "accord de la personne n'est pas obtenu"
    assert_not s.reload.is_active
  end

  test "ni créée directement en ligne" do
    s = Story.new(title: "T", location: "Nancy", latitude: 48.69, longitude: 6.18, veille_candidate: @candidat, is_active: true)
    assert_not s.valid?
  end

  test "avec l'accord, la mise en ligne passe" do
    s = histoire(accord_obtenu_at: Time.current)
    assert s.update(is_active: true)
  end

  test "la case à cocher de l'admin date l'accord sans écraser une date existante, et décocher l'efface" do
    s = histoire
    s.update!(accord_obtenu: "1")
    date = s.accord_obtenu_at
    assert_not_nil date

    s.update!(accord_obtenu: "1")
    assert_equal date, s.reload.accord_obtenu_at

    s.update!(accord_obtenu: "0")
    assert_nil s.reload.accord_obtenu_at
  end

  test "cocher l'accord et publier dans le même enregistrement fonctionne" do
    s = histoire
    assert s.update(accord_obtenu: "1", is_active: true)
  end

  test "une fiche déjà en ligne reste modifiable (la règle ne joue qu'à la mise en ligne)" do
    s = histoire(accord_obtenu_at: Time.current, is_active: true)
    s.update_columns(accord_obtenu_at: nil)
    assert s.reload.update(title: "Nouveau titre")
  end

  test "les fiches saisies à la main ne dépendent pas de l'accord" do
    s = Story.create!(title: "À la main", location: "Nancy", latitude: 48.69, longitude: 6.18)
    assert_not s.accord_requis?
    assert s.update(is_active: true)
  end

  test "la mention « Accord de la personne » du récit suit la colonne" do
    s = histoire(body: "Récit.\n\nSource : X — u\nAccord de la personne : à obtenir")
    s.update!(accord_obtenu_at: Time.zone.local(2026, 11, 3, 10))
    assert_match(/Accord de la personne : obtenu le 03\/11\/2026\z/, s.body)

    s.update!(accord_obtenu_at: nil)
    assert_match(/Accord de la personne : à obtenir\z/, s.body)
  end
end
