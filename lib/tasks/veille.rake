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
