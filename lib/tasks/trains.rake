namespace :trains do
  desc "Extrait du GTFS SNCF limité à Nancy-Ville (SORTIE=livre : écrit db/trains/nancy.json, livré avec l'appli ; sinon tmp/trains/nancy.json). À relancer chaque semaine."
  task extrait: :environment do
    cible = ENV["SORTIE"] == "livre" ? Trains::Horaires::LIVRE : Trains::Horaires::FRAIS
    extrait = Trains::GtfsExtrait.generer(ENV["GTFS_ZIP"])
    Trains::Horaires.ecrire(extrait, cible)
    puts "#{cible} : #{extrait[:trajets].size} courses, #{extrait[:services].size} services, fenêtre #{extrait[:fenetre].join('-')}, flux #{extrait[:feed][:version]}"
  end
end
