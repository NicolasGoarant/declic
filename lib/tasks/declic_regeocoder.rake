# lib/tasks/declic_regeocoder.rake
#
# Rejoue le géocodage (Geocoder / Nominatim, via NancyGeocodable#geocode_and_guard)
# pour une liste de fiches Opportunity, en ESSAI par défaut : affiche l'ancienne et
# la nouvelle position sans rien écrire. N'écrit que si APPLIQUER=1.
#
#   bundle exec rails declic:regeocoder                    # essai, liste par défaut
#   bundle exec rails declic:regeocoder IDS=1521,1817       # essai, liste choisie
#   bundle exec rails declic:regeocoder APPLIQUER=1         # écrit, liste par défaut
#
# La liste par défaut est celle des 6 opportunités mal géocodées relevées le
# 2026-09-21 sur les 90 du diorama (nancy-3d, controle-geocodage-2026-09-21.json —
# fichier hors dépôt, jamais copié ici : seuls les identifiants numériques le sont).

namespace :declic do
  desc "Essai (ou application avec APPLIQUER=1) du regéocodage restreint à Nancy sur une liste de fiches"
  task regeocoder: :environment do
    ids_defaut = [1521, 1562, 1578, 1579, 1586, 1817]
    ids = (ENV["IDS"].presence || ids_defaut.join(",")).split(",").map { |s| s.strip.to_i }.reject(&:zero?)
    appliquer = ENV["APPLIQUER"] == "1"

    puts appliquer ? "MODE APPLICATION — chaque fiche listée sera enregistrée." \
                    : "MODE ESSAI (par défaut) — rien n'est enregistré. Relancer avec APPLIQUER=1 pour écrire."
    puts "Fiches : #{ids.join(', ')}"
    puts

    ids.each do |id|
      o = Opportunity.find_by(id: id)
      if o.nil?
        puts "##{id} : introuvable, ignorée."
        puts
        next
      end

      ancienne_lat, ancienne_lon = o.latitude, o.longitude
      ancien_motif = o.geocoding_flagged_reason

      o.geocode_and_guard

      puts "##{id} — #{o.title}"
      puts "  adresse       : #{o.location}"
      ancien_txt = "#{ancienne_lat.inspect}, #{ancienne_lon.inspect}"
      ancien_txt += " (déjà signalée : #{ancien_motif})" if ancien_motif.present?
      puts "  ancienne pos. : #{ancien_txt}"
      nouvelle_txt = "#{o.latitude.inspect}, #{o.longitude.inspect}"
      nouvelle_txt += " (SIGNALÉE : #{o.geocoding_flagged_reason})" if o.geocoding_flagged_reason.present?
      puts "  nouvelle pos. : #{nouvelle_txt}"

      if appliquer
        o.save(validate: false)
        puts "  -> enregistrée."
      else
        puts "  -> essai seul, rien d'écrit (APPLIQUER=1 pour écrire)."
      end
      puts
    end
  end
end
