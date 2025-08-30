# config/initializers/geocoder.rb
Geocoder.configure(
  # Temps max des requêtes de géocodage
  timeout: 3,

  # Distances en kilomètres (par défaut c'est :mi)
  units: :km,

  # Si tu géocodes des adresses -> utilise Nominatim (ou autre)
  # et fournis un User-Agent comme le recommande OpenStreetMap.
  lookup: :nominatim,
  use_https: true,
  http_headers: { "User-Agent" => "Declic/1.0 (contact@exemple.fr)" },

  # Optionnel : cache en mémoire
  cache: Rails.cache
)
