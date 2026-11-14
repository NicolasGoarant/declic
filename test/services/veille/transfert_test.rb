require "test_helper"
require "rake"
require "tmpdir"

# Export / import des candidats triés (rake veille:exporter_candidats, veille:importer_candidats).
class Veille::TransfertTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("veille:exporter_candidats")
    Veille::Candidate.delete_all
  end

  def candidat(**attrs)
    Veille::Candidate.create!({ url: "https://exemple.fr/#{SecureRandom.hex(4)}", title: "Atelier #{SecureRandom.hex(3)}",
                                origin: "agenda_nancy", status: "pending", item_type: "opportunite", declic_category: "pratiquer",
                                score: 72, reason: "Invite à venir.", full_text: "TEXTE COMPLET", enriched_at: Time.current }.merge(attrs))
  end

  def lancer(tache, env)
    avant = env.keys.to_h { |k| [k, ENV[k]] }
    env.each { |k, v| ENV[k] = v }
    Rake::Task[tache].reenable
    out, = capture_io { Rake::Task[tache].invoke }
    out
  ensure
    avant.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "l'export contient le résultat IA mais ni full_text ni fiche" do
    c = candidat(classement_manuel: true, start_time: "14h30", reason: "Second avis (claude-sonnet-5-5, premier score 55, premier verdict opportunite/decouvrir) : ok")
    json = Veille::Transfert.exporter
    l = json["candidats"].first
    assert_equal c.url, l["url"]
    assert_equal %w[72 true 14:30], [l["score"].to_s, l["classement_manuel"].to_s, l["start_time"]]
    assert_equal({ "score" => 55, "verdict" => "opportunite/decouvrir" }, l["avis_haiku"])
    refute_includes JSON.generate(json), "TEXTE COMPLET"
    %w[full_text draft_body opportunity_id].each { |k| refute l.key?(k) }
  end

  test "la tâche d'export écrit le fichier demandé" do
    candidat
    Dir.mktmpdir do |d|
      f = File.join(d, "c.json")
      out = lancer("veille:exporter_candidats", "SORTIE" => f)
      assert_match(/1 candidats exportés/, out)
      assert_equal 1, JSON.parse(File.read(f))["nombre"]
    end
  end

  test "import : crée, puis rejoué ne crée plus rien (idempotent)" do
    candidat(status: "retenu", classement_manuel: true, start_time: "09:00")
    candidat
    donnees = JSON.parse(JSON.generate(Veille::Transfert.exporter))
    Veille::Candidate.delete_all
    r = Veille::Transfert.importer(donnees)
    assert_equal [2, 0, 0], [r.crees, r.ignores, r.refuses]
    c = Veille::Candidate.find_by(status: "retenu")
    assert c.classement_manuel
    assert_equal "09:00", c.start_time.strftime("%H:%M")
    assert_nil c.full_text
    assert c.enriched_at.present?
    r = Veille::Transfert.importer(donnees)
    assert_equal [0, 2, 0], [r.crees, r.ignores, r.refuses]
    assert_equal 2, Veille::Candidate.count
  end

  test "import : n'écrase jamais une décision manuelle déjà présente" do
    c = candidat(status: "ecarte", discard_reason: "Hors périmètre", classement_manuel: true, declic_category: "decouvrir", score: 10)
    donnees = { "candidats" => [{ "url" => c.url, "title" => c.title, "status" => "retenu", "declic_category" => "pratiquer", "score" => 99, "classement_manuel" => false }] }
    r = Veille::Transfert.importer(donnees)
    assert_equal [0, 1, 0], [r.crees, r.ignores, r.refuses]
    c.reload
    assert_equal %w[ecarte decouvrir 10], [c.status, c.declic_category, c.score.to_s]
    assert c.classement_manuel
  end

  test "import : ne publie rien, refuse les lignes invalides et compte" do
    donnees = { "candidats" => [
      { "url" => "https://a.fr/1", "title" => "Publiée", "status" => "publie" },
      { "url" => "", "title" => "Sans URL", "status" => "pending" },
      { "url" => "https://a.fr/3", "title" => "Catégorie", "status" => "pending", "declic_category" => "nimportequoi" },
      { "url" => "https://a.fr/4", "title" => "Score", "status" => "pending", "score" => 150 },
      { "url" => "https://a.fr/5", "title" => "Bonne", "status" => "a_verifier", "score" => 40 }
    ] }
    r = Veille::Transfert.importer(donnees)
    assert_equal [1, 0, 4], [r.crees, r.ignores, r.refuses]
    assert_equal ["https://a.fr/5"], Veille::Candidate.pluck(:url)
    assert_equal 0, Veille::Candidate.where(status: "publie").count
    assert_equal 0, Opportunity.joins(:veille_candidate).count if Opportunity.reflect_on_association(:veille_candidate)
  end

  test "import : un autre lien vers le même événement (titre et date) est ignoré" do
    candidat(title: "Soirée jeux", starts_on: Date.new(2026, 12, 1))
    r = Veille::Transfert.importer({ "candidats" => [{ "url" => "https://autre.fr/x", "title" => "Soirée jeux", "status" => "pending", "starts_on" => "2026-12-01" }] })
    assert_equal [0, 1, 0], [r.crees, r.ignores, r.refuses]
  end

  test "la tâche d'import en DRY_RUN compte sans écrire" do
    Dir.mktmpdir do |d|
      f = File.join(d, "c.json")
      File.write(f, JSON.generate({ "candidats" => [{ "url" => "https://a.fr/9", "title" => "Nouveau", "status" => "pending" }, { "url" => "", "status" => "pending" }] }))
      out = lancer("veille:importer_candidats", "FICHIER" => f, "DRY_RUN" => "1")
      assert_match(/à blanc.*1 créé\(s\), 0 ignoré\(s\).*1 refusé\(s\)/, out)
      assert_equal 0, Veille::Candidate.count
      out = lancer("veille:importer_candidats", "FICHIER" => f, "DRY_RUN" => nil)
      assert_match(/1 créé\(s\)/, out)
      assert_equal 1, Veille::Candidate.count
    end
  end

  test "la tâche d'import lit l'entrée standard avec FICHIER=-" do
    avant = $stdin
    $stdin = StringIO.new(JSON.generate({ "candidats" => [{ "url" => "https://a.fr/stdin", "title" => "Via stdin", "status" => "pending" }] }))
    out = lancer("veille:importer_candidats", "FICHIER" => "-", "DRY_RUN" => nil)
    assert_match(/1 créé\(s\)/, out)
    assert_equal ["https://a.fr/stdin"], Veille::Candidate.pluck(:url)
  ensure
    $stdin = avant
  end
end
