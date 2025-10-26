# Autorise la géolocalisation depuis l'origine du site
Rails.application.config.permissions_policy do |p|
  p.geolocation :self
end
