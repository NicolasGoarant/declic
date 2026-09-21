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

    hote = ENV["APP_HOST"].presence
    lignes = scope.order(:id).map do |o|
      lat = o.latitude&.to_f
      lon = o.longitude&.to_f
      {
        id: o.id,
        titre: o.title,
        categorie: o.category,
        debut: o.starts_at&.iso8601,
        fin: o.ends_at&.iso8601,
        adresse: o.address.presence || o.location,
        code_postal: o.postal_code.presence || o.postcode,
        commune: o.city,
        latitude: lat,
        longitude: lon,
        chemin: "/opportunities/#{o.slug}",
        url: (hote ? "https://#{hote}/opportunities/#{o.slug}" : nil)
      }
    end

    sans = lignes.count { |l| l[:latitude].nil? || l[:longitude].nil? }
    hors = lignes.count do |l|
      next false if l[:latitude].nil? || l[:longitude].nil?
      !(METROPOLE[:lon].cover?(l[:longitude]) && METROPOLE[:lat].cover?(l[:latitude]))
    end

    dossier = File.join(Dir.home, "Documents", "nancy-3d-declic")
    FileUtils.mkdir_p(dossier)
    chemin = File.join(dossier, "opportunites-#{Date.current.strftime('%Y-%m-%d')}.json")
    File.write(chemin, JSON.pretty_generate(
      exporte_le: maintenant.iso8601, hote: hote, opportunites: lignes
    ))

    puts "✅ #{lignes.size} opportunités exportées -> #{chemin}"
    puts "• sans coordonnées : #{sans}"
    puts "• hors de la boîte de la Métropole : #{hors}"
    puts "• URL publique : #{hote ? 'https://' + hote : 'absente (APP_HOST non défini) — seul `chemin` est écrit'}"
  end
end
