require "test_helper"
require_relative "support"

class Veille::PrefiltreTest < ActiveSupport::TestCase
  include VeilleSupport

  def verdict(titre, texte = nil) = Veille::Prefiltre.evaluer(titre: titre, texte: texte)

  test "retient un élément du Grand Nancy qui relève d'un thème Déclic" do
    assert verdict("Laxou : une association cherche des bénévoles").retenu?
    assert verdict("Un portrait", "Un artisan de Meurthe-et-Moselle a créé son atelier").retenu?
    assert verdict("En Lorraine, une épicerie solidaire ouvre ses portes").retenu?
  end

  test "écarte sans territoire ou sans thème, en disant pourquoi" do
    assert_equal "hors territoire", verdict("Paris : une association cherche des bénévoles").motif
    assert_equal "hors thèmes Déclic", verdict("Nancy : le pont est refait").motif
  end

  test "écarte d'office sport, faits divers, météo, politique nationale, horoscope" do
    {
      "sport" => "Nancy : victoire de l'ASNL, association des supporters ravie",
      "faits_divers" => "Nancy : un accident, une association appelle aux dons",
      "meteo" => "Lorraine : vigilance orange, bénévoles mobilisés",
      "politique_nationale" => "Nancy : le Premier ministre rencontre une association",
      "horoscope" => "Horoscope du jour à Nancy pour les associations"
    }.each do |groupe, titre|
      v = verdict(titre)
      assert_not v.retenu?, titre
      assert_equal "exclusion : #{groupe}", v.motif
    end
  end

  test "compare sur mots entiers : « don » ne retient pas « donnerie »" do
    assert_equal "hors thèmes Déclic", verdict("Nancy : la donnerie ferme").motif
  end

  test "filtrer compte reçus, retenus et écartés par motif" do
    items = [item(title: "Nancy : appel à bénévoles", text: ""), item(title: "Nancy : match de rugby", text: ""),
             item(title: "Paris : appel à bénévoles", text: "")]
    bilan = Veille::Prefiltre.filtrer(items)
    assert_equal [3, 1, 2], [bilan.recus, bilan.retenus.size, bilan.ecartes]
    assert_equal({ "exclusion : sport" => 1, "hors territoire" => 1 }, bilan.motifs)
  end

  test "le runner préfiltre la presse avant stockage et laisse passer les autres sources" do
    presse = [item(origin: "ici_lorraine", title: "Nancy : appel à bénévoles", text: ""),
              item(origin: "ici_lorraine", title: "Nancy : victoire au rugby", text: "")]
    agenda = [item(origin: "agenda_nancy", title: "Concert", text: "", starts_on: Date.new(2026, 11, 20))]
    faux = Struct.new(:items) { def call = Veille::Connectors::Base::Resultat.new(nom: "X", statut: :ok, items: items, message: "") }
    enricher = Object.new.tap { |o| o.define_singleton_method(:enrich) { |_c| nil } }
    rapport = Veille::Runner.new(connecteurs: [faux.new(presse + agenda)], enricher: enricher, redacteur: Object.new, max: 0, http: Object.new,
                                 ingester: Veille::RawIngester.new(today: Date.new(2026, 11, 11))).run

    assert_equal [2, 1, 1], [rapport.prefiltre.recus, rapport.prefiltre.retenus.size, rapport.prefiltre.ecartes]
    assert_equal 2, rapport.crees
    assert_not Veille::Candidate.exists?(title: "Nancy : victoire au rugby")
  end
end
