Geocoder.configure(
  timeout: 3,
  units: :km,
  lookup: :nominatim,
  use_https: true,
  language: :fr,
  http_headers: { "User-Agent" => "Declic/1.0 (contact@exemple.fr)" },
  cache: Rails.cache
)
