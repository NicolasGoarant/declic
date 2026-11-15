require "test_helper"
require "rake"
require_relative "support"

# « Aujourd'hui » / « Ce soir » de l'agenda du Grand Nancy et segments en double (15/11).
class Veille::TextesRelatifsTest < ActiveSupport::TestCase
  include VeilleSupport

  TODAY = Date.new(2026, 11, 15)
  T = Veille::TextesRelatifs

  def nettoyer(texte, debut = nil, fin = nil) = T.nettoyer(texte, starts_on: debut, ends_on: fin)

  test "un jour : le mot relatif est remplacé par la date absolue" do
    texte = "Le vivant et l'art contemporain. Conférence - Rencontre. Lieu : Musée des Beaux-Arts. Aujourd'hui de 18h30 à 20h. Sur réservation"
    assert_equal "Le vivant et l'art contemporain. Conférence - Rencontre. Lieu : Musée des Beaux-Arts. Mercredi 16 décembre 2026 de 18h30 à 20h. Sur réservation",
                 nettoyer(texte, Date.new(2026, 12, 16), Date.new(2026, 12, 16))
    assert_equal "Mardi 8 décembre 2026 à 18h", nettoyer("Ce soir à 18h", Date.new(2026, 12, 8))
  end

  test "plusieurs jours ou date inconnue : le mot est retiré, l'horaire reste" do
    assert_equal "Titre. à 14h", nettoyer("Titre. Aujourd'hui à 14h", Date.new(2026, 12, 9), Date.new(2027, 1, 20))
    assert_equal "Titre. de 20h à minuit", nettoyer("Titre. Ce soir de 20h à minuit")
    assert_equal "Titre. Gratuit", nettoyer("Titre. Ce week-end. Gratuit")
  end

  test "Demain, Hier, Cette semaine en segment de date" do
    assert_equal "Samedi 21 novembre 2026 à 10h", nettoyer("Demain à 10h", Date.new(2026, 11, 21))
    assert_equal "Titre. Gratuit", nettoyer("Titre. Cette semaine. Gratuit")
  end

  test "une phrase de presse n'est jamais réécrite" do
    phrase = "Hier, le conseil municipal a voté le budget et demain tout change"
    assert_equal phrase, nettoyer(phrase, Date.new(2026, 12, 16))
    assert_equal "Réunion demain soir à la mairie", nettoyer("Réunion demain soir à la mairie")
  end

  test "segments identiques consécutifs : un seul, sans toucher aux répétitions non consécutives" do
    assert_equal "Titre. Conférence - Rencontre. Lieu : X", nettoyer("Titre. Conférence - Rencontre. Conférence - Rencontre. Lieu : X")
    assert_equal "A. B. A", nettoyer("A. B. A")
  end

  test "idempotent, et sans effet sur un texte sain" do
    texte = "Titre. Conférence - Rencontre. Conférence - Rencontre. Aujourd'hui à 15h. Gratuit"
    une_fois = nettoyer(texte, Date.new(2026, 12, 16))
    assert_equal une_fois, nettoyer(une_fois, Date.new(2026, 12, 16))
    assert_equal "Rien à changer. Gratuit", nettoyer("Rien à changer. Gratuit", Date.new(2026, 12, 16))
    assert_nil nettoyer(nil)
  end

  test "détection pour l'audit" do
    assert T.relatif?("… Aujourd'hui de 18h à 20h")
    assert T.relatif?("Ce soir")
    assert_not T.relatif?("Hiérarchie des normes")
    assert T.doublon?("A. Activité. Activité. B")
    assert_not T.doublon?("A. B. A")
  end

  # --- connecteur ------------------------------------------------------------------------------------------
  def item(ev)
    base = { "name" => "Le vivant et l'art contemporain", "mainCategory" => { "name" => "Conférence - Rencontre" }, "uuid" => "z",
             "subCategories" => [{ "name" => "Conférence - Rencontre" }], "place" => { "name" => "Musée des Beaux-Arts", "city" => { "name" => "Nancy" } },
             "reservation" => true }
    Veille::Connectors::AgendaNancy.new(http: FakeHttp.new, today: TODAY).item_pour(base.merge(ev))
  end

  test "agenda : Aujourd'hui du 16 décembre devient la date absolue, la rubrique n'est pas répétée, les dates restent dans leurs champs" do
    i = item("startDate" => "2026-12-16T00:00:00+01:00", "endDate" => "2026-12-16T00:00:00+01:00", "dateList" => [{ "date" => "2026-12-16" }],
             "duringDateText" => "Aujourd'hui de 18h30 à 20h", "beforeDateText" => "Mercredi 16 décembre de 18h30 à 20h")
    attrs = i.to_candidate_attributes
    assert_equal "Le vivant et l'art contemporain. Conférence - Rencontre. Lieu : Musée des Beaux-Arts. Commune : Nancy. Mercredi 16 décembre 2026 de 18h30 à 20h. Sur réservation", attrs[:full_text]
    assert_equal attrs[:full_text], attrs[:excerpt]
    assert_no_match(/aujourd/i, attrs[:excerpt])
    assert_equal [Date.new(2026, 12, 16), Date.new(2026, 12, 16)], [attrs[:starts_on], attrs[:ends_on]]
    assert_equal ["18:30", "20:00"], [attrs[:start_time], attrs[:end_time]].map { |t| t.strftime("%H:%M") }
  end

  test "agenda : plusieurs occurrences, la liste des dates (beforeDateText) est gardée avec l'horaire, créneau = première à dernière date" do
    i = item("startDate" => "2026-12-09T00:00:00+01:00", "endDate" => "2027-01-20T00:00:00+01:00",
             "dateList" => [{ "date" => "2026-12-09" }, { "date" => "2027-01-13" }, { "date" => "2027-02-20" }],
             "duringDateText" => "Aujourd'hui à 14h", "beforeDateText" => "Mercredis 9 décembre 2026, 13 janvier et samedi 20 février 2027")
    attrs = i.to_candidate_attributes
    assert_includes attrs[:full_text], "Mercredis 9 décembre 2026, 13 janvier et samedi 20 février 2027 à 14h"
    assert_no_match(/aujourd/i, attrs[:full_text])
    assert_equal [Date.new(2026, 12, 9), Date.new(2027, 1, 20)], [attrs[:starts_on], attrs[:ends_on]]
  end

  test "agenda : un texte de date non relatif reste inchangé" do
    i = item("startDate" => "2026-11-20T00:00:00+01:00", "endDate" => "2027-01-03T00:00:00+01:00",
             "duringDateText" => "Jusqu'au 3 janvier 2027", "beforeDateText" => "Du 20 novembre 2026 au 3 janvier 2027")
    assert_includes i.to_candidate_attributes[:full_text], "Jusqu'au 3 janvier 2027"
  end

  # --- tâche rake ------------------------------------------------------------------------------------------
  def lancer(env = {})
    Rails.application.load_tasks unless Rake::Task.task_defined?("veille:nettoyer_textes")
    Rake::Task["veille:nettoyer_textes"].reenable
    anciens = env.to_h { |k, _| [k, ENV[k]] }
    env.each { |k, v| ENV[k] = v }
    out, = capture_io { Rake::Task["veille:nettoyer_textes"].invoke }
    out
  ensure
    anciens&.each { |k, v| ENV[k] = v }
  end

  test "nettoyer_textes : non publiés seulement, à blanc puis réel, idempotent, sans toucher un texte collé à la main" do
    texte = "Titre. Activité - Animation. Activité - Animation. Aujourd'hui à 15h. Gratuit"
    a = candidat(full_text: texte, excerpt: texte.slice(0, 400), starts_on: Date.new(2026, 12, 16), ends_on: Date.new(2026, 12, 16))
    colle = candidat(full_text: "Texte collé à la main. Hier, il pleuvait. Ce soir à 18h", excerpt: "Titre. Aujourd'hui à 15h. Gratuit",
                     starts_on: Date.new(2026, 12, 16))
    publie = candidat(full_text: texte, excerpt: texte, status: "publie", starts_on: Date.new(2026, 12, 16))

    assert_match(/2 candidat\(s\) à nettoyer/, lancer("DRY_RUN" => "1"))
    assert_equal texte, a.reload.full_text, "à blanc : rien n'est écrit"

    lancer
    assert_equal "Titre. Activité - Animation. Mercredi 16 décembre 2026 à 15h. Gratuit", a.reload.full_text
    assert_equal a.full_text, a.excerpt
    assert_equal "Texte collé à la main. Hier, il pleuvait. Ce soir à 18h", colle.reload.full_text, "full_text collé : intact"
    assert_equal "Titre. Mercredi 16 décembre 2026 à 15h. Gratuit", colle.excerpt, "l'extrait, lui, est nettoyé"
    assert_equal texte, publie.reload.full_text, "publié : intact"

    assert_match(/0 candidat/, lancer)
  end
end
