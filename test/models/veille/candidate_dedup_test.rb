require "test_helper"
require_relative "../../services/veille/support"

class Veille::CandidateDedupTest < ActiveSupport::TestCase
  include VeilleSupport

  test "le titre est normalisé à l'enregistrement" do
    assert_equal "l ete a vandoeuvre", candidat(title: "L'Été à Vandœuvre !").normalized_title
  end

  test "même URL : doublon" do
    c = candidat(url: "https://exemple.fr/a")
    assert Veille::Candidate.doublon?(url: c.url, title: "Tout autre titre")
  end

  test "même titre normalisé et même date : doublon, même sous une autre URL" do
    candidat(title: "Conférence : le Réemploi", starts_on: Date.new(2027, 1, 20))
    assert Veille::Candidate.doublon?(url: "https://autre.fr/x", title: "conference le reemploi!", starts_on: Date.new(2027, 1, 20))
  end

  test "même titre mais autre date : pas un doublon" do
    candidat(title: "Conférence", starts_on: Date.new(2027, 1, 20))
    assert_not Veille::Candidate.doublon?(url: "https://autre.fr/x", title: "Conférence", starts_on: Date.new(2027, 1, 21))
  end

  test "sans date, il faut la même origine pour être un doublon" do
    candidat(title: "Aide aux devoirs", origin: "jeveuxaider")
    assert Veille::Candidate.doublon?(url: "https://autre.fr/x", title: "Aide aux devoirs", origin: "jeveuxaider")
    assert_not Veille::Candidate.doublon?(url: "https://autre.fr/y", title: "Aide aux devoirs", origin: "gazette")
  end

  test "date ou régime tels qu'affichés" do
    assert_equal "Ouvert toute l'année", candidat(schedule_text: "Ouvert toute l'année").quand
    assert_equal "20/01/2027", candidat(starts_on: Date.new(2027, 1, 20)).quand
    assert_equal "20/01/2027 → 22/01/2027", candidat(starts_on: Date.new(2027, 1, 20), ends_on: Date.new(2027, 1, 22)).quand
  end

  test "refuse un type, une catégorie ou une fiabilité inconnus" do
    assert_not Veille::Candidate.new(url: "https://x.fr", item_type: "actualite").valid?
    assert_not Veille::Candidate.new(url: "https://x.fr", declic_category: "culture").valid?
    assert_not Veille::Candidate.new(url: "https://x.fr", reliability: "super").valid?
  end
end
