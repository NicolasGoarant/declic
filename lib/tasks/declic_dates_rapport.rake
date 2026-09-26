# lib/tasks/declic_dates_rapport.rake
# LECTURE SEULE : fait le compte de la reprise des dates des opportunités (règles de
# ConversionDates) sans rien écrire. Utilisable avant la migration (ce qui SERA converti)
# comme après (ce qui l'a été : le texte libre déjà basculé compte comme basculé).
# Une opportunité peut relever de plusieurs lignes (ex. texte libre basculé ET permanente).

namespace :declic do
  desc "Lecture seule : bilan de la conversion des dates des opportunités (ISO, texte libre, permanentes)"
  task dates_rapport: :environment do
    lignes = {
      iso: "dates ISO converties (start_date / end_date -> starts_on / ends_on)",
      reconcilie: "dates reprises de starts_at / ends_at (heure de Paris), restant à écrire",
      texte_bascule: "texte libre basculé dans schedule_text",
      texte_conserve: "texte libre conservé faute de place (schedule_text déjà rempli)",
      permanente: "permanentes (sans date)"
    }
    ids = Hash.new { |h, k| h[k] = [] }
    total = 0
    Opportunity.find_each do |o|
      total += 1
      ConversionDates.new(o).cas.each { |c| ids[c] << o.id }
    end

    puts "Opportunités examinées : #{total}"
    lignes.each { |cas, libelle| puts format("%5d  %s", ids[cas].size, libelle) }
    puts "Texte libre conservé, ids : #{ids[:texte_conserve].join(', ')}" if ids[:texte_conserve].any?
  end
end
