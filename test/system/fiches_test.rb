require "application_system_test_case"

# Pages publiques d'une Opportunité et d'une Belle Histoire, au format mobile. Fiches sans
# coordonnées : pas de mini-carte, donc ni Leaflet ni tuiles à charger.
class FichesTest < ApplicationSystemTestCase
  setup do
    Geocoder::Lookup::Test.set_default_stub([]) # adresses non géocodées : fiches sans carte
    page.driver.browser.manage.window.resize_to(390, 844)
    @base = { description: "Un atelier pour réparer ensemble.", category: "ecologiser", is_active: true,
              location: "MJC Lillebonne, 14 rue du Cheval Blanc, 54000 Nancy", organization: "MJC Lillebonne" }
  end

  def pixel = Rails.root.join("test/fixtures/files/pixel.png")

  test "fiche opportunité datée : en-tête, encart pratique, blocs remplis, bloc d'action, galerie" do
    o = Opportunity.create!(@base.merge(title: "Repair Café", starts_on: Date.current + 3, start_time: "14:00", end_time: "18:00",
                                        programme: [ "Diagnostic", "Réparation" ], audience: "Tout le monde.",
                                        quote: "On répare ensemble.", quote_author: "L'équipe", tags: "Atelier, Zéro déchet",
                                        is_free: true, cta_button_text: "Je m'inscris", cta_button_url: "https://exemple.org/inscription"))
    o.photos.attach([ { io: File.open(pixel), filename: "a.png" }, { io: File.open(pixel), filename: "b.png" } ])

    visit opportunity_path(o)

    assert_selector "h1", text: "Repair Café"
    assert_selector ".fch-badge", text: "Écologiser"
    assert_selector ".fch-publication", text: /Publiée le .* · aujourd'hui/
    assert_selector ".fch-pratique", text: "14h - 18h"
    assert_selector ".fch-pratique strong", text: "MJC Lillebonne"
    assert_selector ".fch-organisateur-initiales", text: "ML"
    assert_selector ".fch-etiquettes li", text: "Gratuit"
    assert_selector "h2", text: "Au programme"
    assert_selector ".fch-frise li", count: 2
    assert_selector ".fch-citation", text: "L'équipe"
    assert_selector ".fch-action a[href='https://exemple.org/inscription']", text: "Je m'inscris"
    assert_selector ".fch-carte-adresse", text: "14 rue du Cheval Blanc"
    assert_no_selector ".fch-terminee"

    assert_selector ".fch-galerie-compteur", text: "1/2"
    find(".fch-galerie-fleche--suiv").click
    assert_selector ".fch-galerie-compteur", text: "2/2"

    find(".fch-action-favori").click
    assert_selector ".fch-action-favori[aria-pressed='true']", text: "Dans vos favoris"
    assert_includes page.evaluate_script("localStorage.getItem('declic:favoris')"), "o#{o.id}"
  end

  test "blocs vides masqués : ni titre ni section sans contenu" do
    o = Opportunity.create!(@base.merge(title: "Permanente minimale", organization: nil, location: nil))

    visit opportunity_path(o)

    assert_selector "h2", text: "En quelques mots"
    assert_no_text "Au programme"
    assert_no_text "À qui s'adresse"
    assert_no_selector ".fch-pratique"
    assert_no_selector ".fch-organisateur"
    assert_no_selector ".fch-etiquettes"
    assert_no_selector ".fch-carte-bloc"
    assert_no_selector ".fch-galerie-compteur"
    assert_selector ".fch-galerie-vide img" # icône de catégorie à la place des photos
    assert_selector ".fch-action" # bloc d'action sans bouton, favoris seulement
    assert_no_selector ".fch-action-bouton"
  end

  test "fiche passée : bandeau terminé, pas de bloc d'action, lien vers les similaires" do
    o = Opportunity.create!(@base.merge(title: "Pitch Night", starts_on: Date.current - 10, cta_button_url: "https://exemple.org"))
    Opportunity.create!(@base.merge(title: "Vélo-École", starts_on: Date.current + 2))

    visit opportunity_path(o)

    assert_selector ".fch-terminee", text: "Cette opportunité est terminée"
    assert_no_selector ".fch-action"
    assert_no_text "Prêt·e à participer"
    assert_selector ".fch-apres a[href='#fch-similaires']"
    assert_selector "#fch-similaires .fch-vignette", text: "Vélo-École"
  end

  test "belle histoire : où se rendre, points forts, source, suggestions, sans bloc d'action ni horaire" do
    s = Story.create!(title: "Serena, parfumeuse", chapo: "Un chapô.", body: "Le récit.", is_active: true,
                      location: "27 rue Frédéric Bazille, 35400 Saint-Malo", venue_name: "Atelier Serena",
                      discover_url: "https://exemple.org/atelier", quote: "Tout part d'un souvenir.", quote_author: "Serena",
                      points_forts: [ { "icone" => "feuille", "titre" => "Nature", "texte" => "Des essences locales." } ],
                      source_name: "France Bleu", source_url: "https://exemple.org/article", source_published_on: Date.new(2026, 2, 1))
    Story.create!(title: "Une autre histoire", body: "…", is_active: true, location: "Nancy")
    Opportunity.create!(@base.merge(title: "Atelier ouvert", starts_on: Date.current + 5))

    visit story_path(s)

    assert_selector ".fch-badge", text: "Belle histoire"
    assert_selector ".fch-pratique h2", text: "Où se rendre Atelier Serena"
    assert_selector ".fch-pratique h2 strong", text: "Atelier Serena"
    assert_no_text "Où rencontrer"
    assert_selector ".fch-pratique a[href='https://exemple.org/atelier']", text: "Découvrir Atelier Serena"
    assert_selector "h2", text: "À propos de cette histoire"
    assert_selector ".fch-points li", text: "Des essences locales."
    assert_selector ".fch-citation", text: "Serena"
    assert_selector ".fch-source", text: "Récit inspiré d'un article de France Bleu, paru le 1 février 2026."
    assert_selector ".fch-source a[href='https://exemple.org/article']", text: "Lire l'article original"
    assert_selector ".fch-suite", text: "Des opportunités pour avoir ton déclic"
    assert_selector ".fch-vignette", text: "Atelier ouvert"
    assert_selector ".fch-vignette", text: "Une autre histoire"

    assert_no_selector ".fch-action"
    assert_no_selector ".fch-action-bouton"
    assert_no_selector ".fch-action-favori"
    assert_no_selector ".fch-pratique svg + p span", text: /\d+h/
  end

  test "belle histoire sans source : bloc Source masqué" do
    s = Story.create!(title: "Sans source", body: "Le récit.", is_active: true, location: "Nancy")

    visit story_path(s)

    assert_no_selector ".fch-source"
    assert_no_text "Récit inspiré"
  end
end
