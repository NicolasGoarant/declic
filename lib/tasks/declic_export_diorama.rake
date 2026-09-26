# lib/tasks/declic_export_diorama.rake
# Exporte les opportunités publiées et à venir, champs PUBLICS seulement, pour le diorama
# du Grand Nancy (dépôt nancy-3d). Le fichier va HORS du dépôt : jamais dans Rails.root.

namespace :declic do
  desc "Exporte les opportunités publiées et à venir en JSON dans ~/Documents/nancy-3d-declic/"
  task export_diorama: :environment do
    require "json"
    require "fileutils"

    # Boîte englobante APPROCHÉE des 20 communes de la Métropole du Grand Nancy (WGS84).
    # C'est un rectangle, pas le contour : il sert à dire « clairement dehors », pas à
    # trancher une commune limitrophe. Le diorama refait le test sur son emprise réelle.
    METROPOLE = { lon: 6.05..6.32, lat: 48.60..48.76 }.freeze

    maintenant = Time.current
    # « Publiée » = is_active (published_at est vide sur toutes les actives : inutilisable).
    # « À venir » = pas terminée : fin future, ou pas de fin et un début futur, ou aucune
    # date (offre permanente : bénévolat, formation). Une fiche expirée est écartée.
    scope = Opportunity.where(is_active: true)
                       .where("expires_at IS NULL OR expires_at >= ?", maintenant)
                       .where("(ends_at IS NOT NULL AND ends_at >= :n) OR " \
                              "(ends_at IS NULL AND (starts_at IS NULL OR starts_at >= :n))", n: maintenant)

    # En production, starts_at / ends_at (datetime) sont quasiment toujours NULL : le
    # formulaire admin écrit encore dans start_date / end_date (string, saisie <input
    # type=date>, donc au format ISO "YYYY-MM-DD"). C'est là que vivent les vraies dates.
    # Quelques valeurs historiques sont du texte libre ("Toute l'année", "Inscriptions
    # jusqu'au ...") : non convertibles, traitées comme absence de date (offre permanente).
    # La règle de lecture est Opportunity.date_iso, partagée avec la page d'accueil.
    hote = ENV["APP_HOST"].presence
    lignes = scope.order(:id).map do |o|
      lat = o.latitude&.to_f
      lon = o.longitude&.to_f
      debut = o.date_debut
      fin   = o.date_fin
      image = if hote.nil?
                nil
              elsif o.image.attached?
                Rails.application.routes.url_helpers.rails_blob_url(o.image, host: hote, protocol: "https")
              elsif o.image_url.present?
                o.image_url =~ /\Ahttps?:\/\//i ? o.image_url : "https://#{hote}/#{o.image_url.delete_prefix('/')}"
              end
      {
        id: o.id,
        titre: o.title,
        categorie: o.category,
        debut: debut&.iso8601,
        fin: fin&.iso8601,
        adresse: o.address.presence || o.location,
        code_postal: o.postal_code.presence || o.postcode,
        commune: o.city,
        latitude: lat,
        longitude: lon,
        image: image,
        chemin: "/opportunities/#{o.slug}",
        url: (hote ? "https://#{hote}/opportunities/#{o.slug}" : nil)
      }
    end

    sans = lignes.count { |l| l[:latitude].nil? || l[:longitude].nil? }
    hors = lignes.count do |l|
      next false if l[:latitude].nil? || l[:longitude].nil?
      !(METROPOLE[:lon].cover?(l[:longitude]) && METROPOLE[:lat].cover?(l[:latitude]))
    end
    avec_date = lignes.count { |l| l[:debut] || l[:fin] }
    avec_image = lignes.count { |l| l[:image] }

    dossier = File.join(Dir.home, "Documents", "nancy-3d-declic")
    FileUtils.mkdir_p(dossier)
    chemin = File.join(dossier, "opportunites-#{Date.current.strftime('%Y-%m-%d')}.json")
    File.write(chemin, JSON.pretty_generate(
      exporte_le: maintenant.iso8601, hote: hote, opportunites: lignes
    ))

    puts "✅ #{lignes.size} opportunités exportées -> #{chemin}"
    puts "• sans coordonnées : #{sans}"
    puts "• hors de la boîte de la Métropole : #{hors}"
    puts "• avec une date (début et/ou fin) : #{avec_date}"
    puts "• avec une image : #{avec_image}"
    puts "• URL publique : #{hote ? 'https://' + hote : 'absente (APP_HOST non défini) — seul `chemin` est écrit'}"
  end
end
