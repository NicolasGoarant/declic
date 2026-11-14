# frozen_string_literal: true

namespace :veille do
  desc "Banc d'essai Haiku 5.5 / Sonnet 5.5 sur des candidats déjà en base — rake veille:banc_essai (ORIGINES=agenda_nancy:20,communes:20, SORTIE=rapports/banc-essai-AAAA-MM-JJ.csv)"
  task banc_essai: :environment do
    abort "❌ ANTHROPIC_API_KEY absent (fichier .env local, ignoré par git)." if ENV["ANTHROPIC_API_KEY"].blank?

    origines = ENV.fetch("ORIGINES", "agenda_nancy:20,communes:20").split(",").to_h { |p| o, n = p.split(":"); [o.strip, Integer(n || 20)] }
    sortie   = ENV.fetch("SORTIE", "rapports/banc-essai-#{Date.current.iso8601}.csv")
    banc     = Veille::BancEssai.new(modele_a: ENV.fetch("MODELE_A", "claude-haiku-5-5"), modele_b: ENV.fetch("MODELE_B", "claude-sonnet-5-5"))

    candidats = banc.choisir(origines, autorisation: ENV["AUTORISATION_ECRITE"] == "1")
    abort "❌ Aucun candidat en base pour #{origines.keys.join(', ')}." if candidats.empty?

    puts "→ #{candidats.size} éléments, #{banc.modele_a} puis #{banc.modele_b} (≈ #{format('%.2f', candidats.size * 0.02)} $ au plus)"
    lignes = banc.run(candidats)
    File.write(sortie, Veille::BancEssai.csv(lignes))
    r = Veille::BancEssai.resume(lignes)
    puts "CSV : #{sortie}"
    puts "Accord de type : #{r[:accord_pct]} % sur #{r[:compares]} éléments comparés ; écart moyen de score : #{r[:ecart_score_moyen]} points"
    puts format("Coût mesuré pour 100 éléments : %s %.4f $ · %s %.4f $", banc.modele_a, r[:cout_a_100], banc.modele_b, r[:cout_b_100])
  end

  desc "Reporte dans le journal des coûts les appels d'un banc déjà lancé — rake veille:reporter_banc CSV=rapports/banc-essai-2026-11-11.csv DATE=2026-11-11"
  task reporter_banc: :environment do
    csv  = ENV.fetch("CSV")
    date = Date.iso8601(ENV.fetch("DATE"))
    n = Veille::BancEssai.reporter(csv, date: date)
    puts n.zero? ? "Rien reporté (déjà fait pour le #{date}, ou CSV vide)." : "#{n} appels reportés (origine banc_essai, #{date}). Dépense du mois : #{format('%.4f', Veille::Plafond.depense(date))} $."
  end
end
