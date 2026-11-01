require "application_system_test_case"
require "minitest/mock"

# Le circuit complet dans un vrai navigateur : le geste dans /admin/veille met la fiche en ligne, et
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
    visit "http://veille-test:secret-de-test@#{serveur.host}:#{serveur.port}/admin/veille"
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

  test "Valider publie la fiche, visible sur la carte via la bascule" do
    DioramaTuiles.stub(:new, @tuiles) do
      candidat(title: "Vide-grenier de test", commune: "Nancy", starts_on: 7.days.from_now.to_date)

      admin "/admin/veille"
      accept_confirm { click_button "Valider" }
      assert_text "En ligne : Vide-grenier de test"
      assert_selector ".flash.notice a[target=_blank]", text: "Voir la fiche publiée"

      assert_visible_sur_la_carte_a_la_demande "Vide-grenier de test"
    end
  end

  test "un élément à localiser se publie dès que sa commune est saisie" do
    DioramaTuiles.stub(:new, @tuiles) do
      c = candidat(title: "Brocante sans commune")

      admin "/admin/veille?a_localiser=1"
      assert_text "à localiser"
      assert_no_button "Valider"
      click_link "Localiser →"

      fill_in "Commune", with: "Nancy"
      click_button "Localiser et publier"
      assert_text "En ligne : Brocante sans commune"
      assert_selector ".flash.notice a[target=_blank]", text: "Voir la fiche publiée"
      assert_equal "publie", c.reload.status

      assert_visible_sur_la_carte_a_la_demande "Brocante sans commune"
    end
  end
end
