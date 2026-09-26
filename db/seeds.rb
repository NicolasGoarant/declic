# db/seeds.rb — données de démonstration (fictives mais plausibles, ancrées dans le Grand Nancy).
#
#   bin/rails db:seed
#
# Relançable à volonté : le fichier repart d'une table vide (mêmes comptes à chaque passage).
# Contenu : db/seeds/opportunites.rb (20 opportunités) et db/seeds/histoires.rb (6 Belles Histoires).
# Photos : db/seeds/images/*.jpg (1600 px max), attachées via Active Storage dans `photos`,
# avec `photos_order`. Lieux publics réels possibles ; organisations, personnes et sources fictives.

# Ce fichier VIDE les tables Story et Opportunity : jamais en production sans accord explicite.
if Rails.env.production? && ENV["SEED_ALLOW_DESTROY"] != "oui"
  abort "db/seeds.rb refuse de s'exécuter en production : il supprime toutes les histoires et " \
        "opportunités. Pour le forcer quand même : SEED_ALLOW_DESTROY=oui bin/rails db:seed"
end

module SeedsDemo
  IMAGES = Rails.root.join("db/seeds/images")

  # Attache les photos (noms de fichiers sans extension, dans l'ordre voulu) et fixe photos_order.
  def self.joindre_photos(fiche, cles)
    cles.each do |cle|
      fiche.photos.attach(io: File.open(IMAGES.join("#{cle}.jpg")), filename: "#{cle}.jpg", content_type: "image/jpeg")
    end
    fiche.update_columns(photos_order: fiche.photos.attachments.reload.map(&:id).sort) if cles.any?
  end
end

# Analyse des images en séquence : sinon les jobs async écrivent en même temps que le seed (SQLite « database is locked »).
ActiveJob::Base.queue_adapter = :inline

puts "🧹 Nettoyage de la base de données..."
# Purge synchrone des fichiers : sinon les blobs des fiches supprimées resteraient orphelins.
ActiveStorage::Attachment.where(record_type: %w[Story Opportunity]).find_each(&:purge)
Story.destroy_all
Opportunity.destroy_all

puts "🌱 Création des opportunités..."
load Rails.root.join("db/seeds/opportunites.rb")

puts "📖 Création des Belles Histoires..."
load Rails.root.join("db/seeds/histoires.rb")

puts "✅ #{Opportunity.count} opportunités (#{Opportunity.actuelles.count} en cours ou à venir, " \
     "#{Opportunity.count - Opportunity.actuelles.count} passées) et #{Story.count} Belles Histoires créées."
