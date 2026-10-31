# frozen_string_literal: true

namespace :veille do
  desc "Importe une liste d'URL (une par ligne) et qualifie chaque candidat — rake veille:import[fichier.txt]"
  task :import, [:fichier] => :environment do |_t, args|
    fichier = args[:fichier].presence || abort("❌ Usage : rake veille:import[chemin/vers/urls.txt]")
    abort "❌ Fichier introuvable : #{fichier}" unless File.file?(fichier)

    urls = File.readlines(fichier, chomp: true)
                .map(&:strip)
                .reject { |l| l.empty? || l.start_with?("#") }
                .uniq

    abort "❌ Aucune URL exploitable dans #{fichier}" if urls.empty?

    puts "→ #{urls.size} URL à traiter depuis #{fichier}"
    puts "→ Qualification avec #{Veille::Qualifier::MODEL}"
    puts ""

    stats     = Hash.new(0)
    qualifier = Veille::Qualifier.new

    urls.each_with_index do |url, i|
      tag = "[#{i + 1}/#{urls.size}] #{url[0, 70]}"

      if Veille::Candidate.exists?(url: url)
        puts "#{tag}\n    ⏭  déjà en base"
        stats[:deja_connus] += 1
        next
      end

      # Une seconde entre deux requêtes vers les sites d'éditeurs.
      # Le sleep vient AVANT le fetch et saute le premier tour, pour ne pas
      # attendre inutilement quand tout est déjà en base.
      sleep 1 unless stats[:fetchees].zero?
      stats[:fetchees] += 1

      begin
        page = Veille::PageFetcher.new.fetch(url)
      rescue Veille::PageFetcher::Error => e
        puts "#{tag}\n    ❌ récupération : #{e.message}"
        stats[:erreurs_fetch] += 1
        next
      end

      candidate = Veille::Candidate.new(
        url:          url,
        title:        page[:title],
        excerpt:      page[:excerpt],
        published_on: page[:published_on],
        source:       Veille::Source.find_by(id: page[:source_id])
      )

      unless candidate.save
        puts "#{tag}\n    ❌ création : #{candidate.errors.full_messages.join(', ')}"
        stats[:erreurs_creation] += 1
        next
      end

      stats[:crees] += 1
      puts "#{tag}\n    ✅ ##{candidate.id} — #{candidate.title.to_s[0, 70]}"

      begin
        qualifier.qualify(candidate)
        stats[:qualifies] += 1
        stats[:belles_histoires] += 1 if candidate.reload.belle_histoire?
        puts "       #{candidate.category} · score #{candidate.score} · #{candidate.reason.to_s[0, 90]}"
      rescue AnthropicClient::Error, Veille::AiPass::ParseError => e
        # Le candidat reste en base sans qualification : il est repassable.
        puts "       ⚠  qualification : #{e.class.name.demodulize} — #{e.message[0, 100]}"
        stats[:erreurs_qualif] += 1
      end
    end

    puts ""
    puts "── Bilan ──────────────────────────────────────────"
    puts "  candidats créés          : #{stats[:crees]}"
    puts "  qualifiés belle_histoire : #{stats[:belles_histoires]}"
    puts "  qualifiés autre          : #{stats[:qualifies] - stats[:belles_histoires]}"
    puts "  URL déjà en base         : #{stats[:deja_connus]}"
    if stats[:erreurs_fetch] + stats[:erreurs_creation] + stats[:erreurs_qualif] > 0
      puts "  échecs récupération      : #{stats[:erreurs_fetch]}"
      puts "  échecs création          : #{stats[:erreurs_creation]}"
      puts "  échecs qualification     : #{stats[:erreurs_qualif]} (candidats conservés, repassables)"
    end
    puts "  À trancher : #{Rails.application.routes.url_helpers.admin_veille_candidates_path}"
  end
end

# --- Veille automatique -----------------------------------------------------
# Heroku Scheduler : « rake veille:quotidien » chaque jour ; « rake veille:hebdomadaire »
# chaque jour aussi (le Scheduler n'a pas de cadence hebdomadaire) : la tâche ne
# travaille que le lundi, sauf FORCE=1. Clés : ANTHROPIC_API_KEY, ENGAGEMENT_API_KEY.
namespace :veille do
  def afficher_rapport(rapport)
    puts "── Sources ─────────────────────────────────────────"
    rapport.sources.each { |s| puts format("  %-20s %-9s %s", s.nom, s.statut, s.message) }
    puts "── Bilan ───────────────────────────────────────────"
    puts "  nouveaux éléments ingérés : #{rapport.crees}"
    puts "  doublons / hors zone / passés : #{rapport.doublons} / #{rapport.hors_zone} / #{rapport.passes}"
    puts "  enrichis (IA)             : #{rapport.enrichis} (dont #{rapport.ecartes} écartés), erreurs IA #{rapport.erreurs_ia}"
    puts "  en attente d'enrichissement : #{rapport.restants}"
    puts "  récits rédigés (IA)       : #{rapport.rediges} (dont #{rapport.redaction_bloquee} à vérifier), erreurs #{rapport.erreurs_redaction}, en attente #{rapport.a_rediger_restants}"
    puts "  PLAFOND MENSUEL ATTEINT : plus aucun appel IA ce mois-ci" if rapport.plafond
    puts "  coût estimé               : #{format('%.4f', rapport.cout_usd)} USD"
    puts "  À relire : #{Rails.application.routes.url_helpers.admin_veille_root_path}"
  end

  desc "Veille quotidienne : sources 1 à 5, 30 éléments enrichis au plus"
  task quotidien: :environment do
    afficher_rapport(Veille::Runner.new(connecteurs: Veille::Runner::QUOTIDIEN).run)
  end

  desc "Veille hebdomadaire : alertes de presse (le lundi, sauf FORCE=1)"
  task hebdomadaire: :environment do
    if Date.current.monday? || ENV["FORCE"] == "1"
      afficher_rapport(Veille::Runner.new(connecteurs: Veille::Runner::HEBDOMADAIRE).run)
    else
      puts "Pas lundi : rien à faire (FORCE=1 pour forcer)."
    end
  end

  desc "Importe le repérage initial — rake veille:import_xlsx[docs/declic-reperage-v1-2026-10-13.xlsx]"
  task :import_xlsx, [:fichier] => :environment do |_t, args|
    fichier = args[:fichier].presence || "docs/declic-reperage-v1-2026-10-13.xlsx"
    abort "❌ Fichier introuvable : #{fichier}" unless File.file?(fichier)

    bilan = Veille::XlsxImporter.new(fichier).call
    puts "Onglets lus : #{bilan.onglets.join(' | ').presence || 'aucun (noms attendus : « Opportunités », « Belles Histoires - pistes »)'}"
    puts "créés #{bilan.crees} · déjà connus #{bilan.doublons} · lignes ignorées #{bilan.ignores}"
  end
end
