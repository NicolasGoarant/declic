require "application_system_test_case"
require "minitest/mock"

# La sélection multiple de la page Presse dans un vrai navigateur : bouton désactivé sans case
# cochée, « tout sélectionner », puis écartement groupé et liste réaffichée sans les articles.
class VeillePresseSelectionTest < ApplicationSystemTestCase
  setup do
    @avant = ENV.values_at("ADMIN_USERNAME", "ADMIN_PASSWORD")
    ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = "veille-test", "secret-de-test"
    liens = (1..4).map do |i|
      ::Veille::Connectors::Presse::Lien.new(titre: "Article numéro #{i}", url: "https://www.estrepublicain.fr/societe/article-#{i}",
                                             flux: "L'Est Républicain", publie_le: Time.zone.local(2026, 10, 31, 8, i))
    end
    @lecteur = Struct.new(:lister).new(::Veille::Connectors::Presse::Lecture.new(liens: liens, erreurs: {}))
  end

  teardown { ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"] = @avant }

  def ouvrir_presse
    serveur = Capybara.current_session.server
    visit "http://veille-test:secret-de-test@#{serveur.host}:#{serveur.port}/admin/veille"
    visit "/admin/veille/presse"
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until evaluate_script("!!window.Turbo") }
  end

  def case_de(n) = find("input[aria-label='Sélectionner : Article numéro #{n}']")
  def cocher(n) = case_de(n).check
  def decocher(n) = case_de(n).uncheck

  test "écarter la sélection : bouton désactivé, cases, tout sélectionner, liste sans les articles écartés" do
    ::Veille::Connectors::Presse.stub(:new, @lecteur) do
      ouvrir_presse
      assert_button "Écarter la sélection", disabled: true

      cocher 1
      cocher 3
      assert_button "Écarter la sélection", disabled: false
      assert_text "2 sélectionnés"

      decocher 1
      decocher 3
      assert_button "Écarter la sélection", disabled: true

      find("input[data-selection-target=tout]").check
      assert_text "4 sélectionnés"
      decocher 4
      assert_text "3 sélectionnés"
      decocher 2
      decocher 3
      cocher 2
      cocher 3

      click_button "Écarter la sélection"
      assert_text "3 articles écartés"
      assert_no_text "Article numéro 1"
      assert_no_text "Article numéro 2"
      assert_no_text "Article numéro 3"
      assert_text "Article numéro 4"
      assert_equal 3, ::Veille::PresseEcartee.count
    end
  end
end
