require "application_system_test_case"
require "minitest/mock"

# Le circuit complet dans un vrai navigateur : le geste dans la galerie d'administration met la fiche en ligne, et
# elle apparaît sur la carte publique, masquée tant que le visiteur n'active pas sa bascule.
class VeillePublicationTest < ApplicationSystemTestCase
  setup do
    @avant = ENV.values_at("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
    @tuiles = DioramaTuiles.new(base: "https://tuiles.test/#{SecureRandom.hex(4)}", sonde: ->(_) { false })
    Geocoder::Lookup::Test.add_stub("Nancy", [{ "latitude" => 48.6937, "longitude" => 6.1834, "address" => "Nancy" }])
  end

  teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @avant }

  def candidat(**attrs)
    Veille::Candidate.create!({ url: "https://exemple.fr/#{SecureRandom.hex(4)}", origin: "agenda_nancy", item_type: "opportunite",
                                declic_category: "decouvrir", famille: "petite_manifestation", summary: "Un résumé reformulé.",
                                reliability: "haute", enriched_at: Time.current }.merge(attrs))
  end

  def admin(chemin)
    serveur = Capybara.current_session.server
    # Identifiants dans l'URL une seule fois : Chrome les retient, et une page dont l'adresse les porte
    # empêcherait Turbo de prendre en charge le formulaire (comme chez un vrai administrateur, ils n'y sont pas).
    visit "http://veille-test:secret-de-test@#{serveur.host}:#{serveur.port}/admin/galerie"
    visit chemin
    # La confirmation de « Valider » est portée par Turbo, chargé en module après la page.
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until evaluate_script("!!window.Turbo") }
  end

  def assert_visible_sur_la_carte_a_la_demande(titre)
    visit labo_opportunites_path
    assert_no_text titre
    click_button "Brocantes, foires et fêtes"
    assert_text titre
  end

  # Depuis la fusion de la relecture dans la galerie (6cee4fe, 5114b55, 14/11), /admin/veille redirige vers
  # /admin/galerie : on y publie d'un clic (« ✓ Publier ») ou depuis l'écran du candidat (« Valider et publier »).
  test "✓ Publier (carte de la galerie) publie la fiche, visible sur la carte via la bascule" do
    DioramaTuiles.stub(:new, @tuiles) do
      c = candidat(title: "Vide-grenier de test", commune: "Nancy", starts_on: 7.days.from_now.to_date)

      admin "/admin/galerie?statut=a_relire"
      find("form.bouton[action$='/valider'] button", text: "✓ Publier").click # la barre d'actions groupées porte aussi un « ✓ Publier »
      assert_text "En ligne : Vide-grenier de test"
      assert_selector ".flash.notice a[target=_blank]", text: "Voir la fiche publiée"
      assert_equal "publie", c.reload.status

      assert_visible_sur_la_carte_a_la_demande "Vide-grenier de test"
    end
  end

  test "Valider et publier (écran du candidat) publie la fiche après confirmation" do
    DioramaTuiles.stub(:new, @tuiles) do
      c = candidat(title: "Brocante du quartier", commune: "Nancy", starts_on: 7.days.from_now.to_date)

      admin admin_veille_candidate_path(c)
      accept_confirm { click_button "Valider et publier" }
      assert_text "En ligne : Brocante du quartier"
      assert_selector ".flash.notice a[target=_blank]", text: "Voir la fiche publiée"
      assert_equal "publie", c.reload.status

      assert_visible_sur_la_carte_a_la_demande "Brocante du quartier"
    end
  end

  test "un élément à localiser se publie dès que sa commune est saisie" do
    DioramaTuiles.stub(:new, @tuiles) do
      c = candidat(title: "Brocante sans commune")

      admin "/admin/galerie?statut=a_relire&a_localiser=1"
      # Niveau 1, l'interface : pas de « ✓ Publier » sur la carte, un bouton inactif « Localiser d'abord ».
      assert_no_selector "form.bouton[action$='/valider']"
      assert_button "Localiser d'abord", disabled: true
      assert_equal "true", find_button("Localiser d'abord", disabled: true)["aria-disabled"]
      # Niveau 2, le serveur : même sans le bouton, une publication directe est refusée.
      evaluate_async_script("fetch('#{valider_admin_veille_candidate_path(c)}', { method: 'POST', redirect: 'manual' }).then(() => arguments[0](true))")
      assert_equal "pending", c.reload.status
      assert_equal 0, Opportunity.where(title: "Brocante sans commune").count
      click_link "Localiser"

      assert_no_button "Valider et publier"
      fill_in "Commune", with: "Nancy"
      click_button "Localiser et publier"
      assert_text "En ligne : Brocante sans commune"
      assert_selector ".flash.notice a[target=_blank]", text: "Voir la fiche publiée"
      assert_equal "publie", c.reload.status

      assert_visible_sur_la_carte_a_la_demande "Brocante sans commune"
    end
  end
end
