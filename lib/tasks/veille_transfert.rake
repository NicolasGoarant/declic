# frozen_string_literal: true

namespace :veille do
  desc "Exporte les candidats triés (résultat IA, sans full_text ni fiches) en JSON — rake veille:exporter_candidats (SORTIE=tmp/candidats-veille-AAAA-MM-JJ.json). Le fichier ne se versionne jamais."
  task exporter_candidats: :environment do
    sortie = ENV.fetch("SORTIE", Rails.root.join("tmp", "candidats-veille-#{Date.current.iso8601}.json").to_s)
    donnees = Veille::Transfert.exporter
    File.write(sortie, JSON.pretty_generate(donnees))
    puts "#{donnees['nombre']} candidats exportés dans #{sortie}"
  end

  desc "Importe un export de candidats — rake veille:importer_candidats FICHIER=tmp/candidats-veille-AAAA-MM-JJ.json (ou FICHIER=- pour lire l'entrée standard, utile avec heroku run) [DRY_RUN=1]. Idempotent, n'écrase rien, ne publie rien."
  task importer_candidats: :environment do
    fichier = ENV["FICHIER"].presence or abort "FICHIER=... manquant."
    abort "Fichier introuvable : #{fichier}" unless fichier == "-" || File.exist?(fichier)
    sec = ENV["DRY_RUN"].present?
    r = Veille::Transfert.importer(JSON.parse(fichier == "-" ? $stdin.read : File.read(fichier)), dry_run: sec)
    puts "Import #{'(à blanc, rien écrit) ' if sec}: #{r.crees} créé(s), #{r.ignores} ignoré(s) (déjà présents), #{r.refuses} refusé(s)."
    r.detail_ignores.each { |motif, n| puts "  ignorés — #{motif} : #{n}" }
    r.detail_refus.each { |l| puts "  refusé — #{l}" }
  end
end
