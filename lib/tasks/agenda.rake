namespace :agenda do
  desc "Prépare les variantes WebP des photos de l'agenda de l'accueil (évite le calcul au premier visiteur)"
  task variantes: :environment do
    Opportunity.active.prochaines.with_attached_photos.with_attached_image.find_each do |o|
      photo = o.couverture
      next unless photo&.variable?

      AccueilHelper::VARIANTES_PHOTO.each_value { |options| photo.variant(options).processed }
      puts "##{o.id} ok"
    end
  end
end
