require "test_helper"
require "rake"
require_relative "support"
require_relative "fake_anthropic_client"

# État de dépense (Cout.etat_du_mois) et tâches rake veille:rediger / veille:cout.
class Veille::CoutEtatTest < ActiveSupport::TestCase
  include VeilleSupport

  RECIT = "Elle a rouvert la porte d'un ancien atelier de couture, au cœur du quartier. Depuis, des voisins y apprennent " \
          "les gestes de la réparation. Autour de la machine à coudre, les conversations se nouent."

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("veille:cout")
  end

  def appel(cout, passe: "redaction", statut: "ok", modele: "claude-sonnet-5", quand: Time.current)
    Veille::AppelIa.create!(passe: passe, modele: modele, statut: statut, cout_usd: cout, created_at: quand)
  end

  def sortie(tache, *args, env: {})
    avant = env.keys.to_h { |k| [k, ENV[k]] }
    env.each { |k, v| ENV[k] = v }
    Rake::Task[tache].reenable
    out, = capture_io { Rake::Task[tache].invoke(*args) }
    out
  ensure
    avant.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "etat_du_mois totalise le mois, par passe, statut et modèle, et compare au plafond" do
    appel(1.0)
    appel(0.5, passe: "enrichissement", modele: "claude-haiku-4-5-20251001")
    appel(0.0, statut: "erreur_api")
    appel(40.0, quand: 1.month.ago.beginning_of_month + 2.days)

    e = Veille::Cout.etat_du_mois
    assert_equal 3, e.appels
    assert_in_delta 1.5, e.depense, 1e-9
    assert_equal 15.0, e.budget
    assert_in_delta 13.5, e.reste, 1e-9
    assert_not e.atteint?
    assert_equal 2, e.par_passe["redaction"][:appels]
    assert_in_delta 0.5, e.par_passe["enrichissement"][:cout], 1e-9
    assert_equal 1, e.par_statut["erreur_api"][:appels]
    assert_equal %w[claude-haiku-4-5-20251001 claude-sonnet-5], e.par_modele.keys.sort
  end

  test "etat_du_mois d'un autre mois" do
    appel(40.0, quand: Time.zone.local(2026, 9, 15))
    e = Veille::Cout.etat_du_mois(Date.new(2026, 9, 1))
    assert_in_delta 40.0, e.depense, 1e-9
    assert e.atteint?
    assert_equal 0.0, e.reste
    assert_equal 0, Veille::Cout.etat_du_mois(Date.new(2026, 8, 1)).appels
  end

  test "rake veille:cout[AAAA-MM] affiche la dépense du mois demandé" do
    appel(2.5, quand: Time.zone.local(2026, 9, 15))
    out = sortie("veille:cout", "2026-09")
    assert_includes out, "2026-09"
    assert_includes out, "1 appel(s) · 2.5000 $ sur un plafond de 15.00 $"
    assert_includes out, "par passe"
    assert_includes out, "claude-sonnet-5"
  end

  test "rake veille:cout sans argument prend le mois courant, et signale le plafond atteint" do
    appel(20.0)
    out = sortie("veille:cout")
    assert_includes out, Date.current.strftime("%Y-%m")
    assert_includes out, "PLAFOND ATTEINT"
  end

  test "rake veille:cout refuse un mois mal formé" do
    assert_raises(SystemExit) { capture_io { Rake::Task["veille:cout"].tap(&:reenable).invoke("octobre") } }
  end

  test "Runner#rattraper_redactions rédige sans collecter ni enrichir" do
    a_enrichir = candidat(title: "Pas encore enrichi")
    h = candidat(origin: "presse", item_type: "belle_histoire", commune: "Laxou", summary: "Un jardin naît.", enriched_at: Time.current, full_text: nil)
    client = FakeAnthropicClient.new(text: { brouillon: RECIT, personne: "X", champs_manquants: [] }.to_json)
    rapport = Veille::Runner.new(connecteurs: [], redacteur: Veille::Redaction::Brouillon.new(client: client)).rattraper_redactions

    assert_equal 1, rapport.rediges
    assert_equal "redige", h.reload.draft_status
    assert_nil a_enrichir.reload.enriched_at, "aucun enrichissement n'est lancé"
    assert_equal 1, client.calls.size
  end

  test "rake veille:rediger sans rien à rédiger ne fait aucun appel" do
    out = sortie("veille:rediger")
    assert_includes out, "0 récit(s) à rédiger"
    assert_includes out, "rédigés : 0"
    assert_equal 0, Veille::AppelIa.count
  end

  test "rake veille:rediger refuse une LIMITE invalide" do
    assert_raises(SystemExit) { sortie("veille:rediger", env: { "LIMITE" => "abc" }) }
  end
end
