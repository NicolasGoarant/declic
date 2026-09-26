# lib/tasks/declic_dates_demo.rake
# Donne des dates À VENIR (dans les 14 jours) à une dizaine d'opportunités de la base de DEV,
# pour voir vivre le volet de /labo/accueil (étiquettes « Aujourd'hui », « Demain »…, filtres
# « Aujourd'hui » et « Cette semaine »). Écrit start_date / end_date au format ISO, comme le
# formulaire admin. Refuse de tourner hors développement.

namespace :declic do
  desc "DEV seulement : dates de démonstration dans les 14 jours sur ~10 opportunités géolocalisées"
  task :dates_demo do
    # Vérifié AVANT de charger l'environnement : rien de la production n'est même initialisé.
    abort "declic:dates_demo refuse de s'exécuter hors développement (RAILS_ENV=#{Rails.env})." unless Rails.env.development?
    Rake::Task[:environment].invoke

    # [décalage du début en jours, durée en jours] : aujourd'hui, demain, dans la semaine, au-delà.
    calendrier = [ [ 0, 0 ], [ 0, 2 ], [ 1, 0 ], [ 2, 0 ], [ 3, 1 ], [ 5, 0 ], [ 6, 0 ], [ 8, 0 ], [ 10, 3 ], [ 13, 0 ] ].freeze

    jour = Date.current
    cibles = Opportunity.active.with_coords.order(:id).limit(calendrier.size).to_a
    cibles.zip(calendrier).each do |opportunite, (decalage, duree)|
      debut = jour + decalage
      fin = debut + duree
      # update_columns : des données de démonstration ne doivent pas buter sur une validation.
      opportunite.update_columns(start_date: debut.iso8601, end_date: fin.iso8601)
      puts format("#%-4d %s → %s  %s", opportunite.id, debut, fin, opportunite.title.to_s.truncate(60))
    end
    puts "#{cibles.size} opportunités datées entre le #{jour} et le #{jour + 14}."
  end
end
