# app/models/concerns/nancy_geocodable.rb
#
# Restreint le géocodage (Geocoder / Nominatim) à l'emprise du Grand Nancy, et
# refuse d'enregistrer un résultat trop loin au lieu de le garder.
#
# LE CAS QUI A DÉCLENCHÉ CECI : la fiche « MJC Desforges » (adresse réelle à
# Nancy, 27 Rue de la République) a été géocodée dans le LOIRET, à 279 km —
# Nominatim a pris « Desforges » pour un toponyme. Rien dans la requête ni
# dans la réponse ne le signalait : la fiche s'est enregistrée avec des
# coordonnées fausses, silencieusement.
#
# DEUX GARDE-FOUS, PAS UN SEUL :
#   1. la recherche elle-même est bornée à la Métropole (`viewbox` +
#      `bounded=1`), pour que Nominatim ne propose même pas un résultat
#      ailleurs en France ;
#   2. un résultat qui passerait quand même à plus de 30 km de Nancy est
#      REFUSÉ après coup et signalé, jamais enregistré — parce qu'un filtre
#      côté requête peut être contourné (nom de commune homonyme ailleurs
#      dans la boîte, ou boîte mal ajustée), et qu'un garde-fou sur le
#      RÉSULTAT ne dépend pas de la qualité de la requête.
module NancyGeocodable
  extend ActiveSupport::Concern

  # Boîte englobante des 20 communes de la Métropole du Grand Nancy, WGS84.
  # Mêmes valeurs que `METROPOLE` dans `lib/tasks/declic_export_diorama.rake`
  # (mesurées sur `communes-grand-nancy.geojson` du dépôt nancy-3d, IGN BD
  # TOPO, reprojeté EPSG:2154 -> EPSG:4326) : un seul rectangle pour tout le
  # dépôt, pas deux qui pourraient diverger.
  VIEWBOX = { min_lon: 6.05, min_lat: 48.60, max_lon: 6.32, max_lat: 48.76 }.freeze

  # Position de référence du garde-fou de distance : place Stanislas.
  REFERENCE_POINT = [48.6937, 6.1834].freeze # [lat, lon]

  MAX_DISTANCE_FROM_NANCY_KM = 30

  # Paramètres Nominatim qui bornent la RECHERCHE elle-même. `bounded => 1`
  # est ce qui rend `viewbox` strict : sans lui, Nominatim ne fait que
  # préférer les résultats dans la boîte, il ne les impose pas.
  NOMINATIM_PARAMS = {
    viewbox: [VIEWBOX[:min_lon], VIEWBOX[:max_lat], VIEWBOX[:max_lon], VIEWBOX[:min_lat]].join(","),
    bounded: 1,
    countrycodes: "fr"
  }.freeze

  class_methods do
    # Comme `geocoded_by`, mais qui ajoute NOMINATIM_PARAMS aux options
    # `params:` déjà données (et les leur laisse la priorité si elles
    # redéfinissent une même clé — un appelant qui sait ce qu'il fait peut
    # toujours se substituer à la boîte par défaut).
    def nancy_geocoded_by(location_attr, **options)
      given_params = options[:params]
      merged = lambda do |obj|
        extra = given_params.respond_to?(:call) ? given_params.call(obj) : (given_params || {})
        NOMINATIM_PARAMS.merge(extra)
      end
      geocoded_by(location_attr, **options.merge(params: merged))
    end
  end

  # Distance en kilomètres à la position de référence (place Stanislas).
  # nil si l'objet n'a pas de coordonnées.
  def distance_to_nancy_km
    return nil if latitude.blank? || longitude.blank?

    Geocoder::Calculations.distance_between(REFERENCE_POINT, [latitude, longitude], units: :km)
  end

  def far_from_nancy?
    d = distance_to_nancy_km
    d.present? && d > MAX_DISTANCE_FROM_NANCY_KM
  end

  # Appelle `geocode` (fourni par `geocoded_by`/`nancy_geocoded_by`) puis
  # applique le garde-fou de distance : un résultat trop loin est REJETÉ —
  # les coordonnées reviennent à `nil` et le motif s'écrit dans
  # `geocoding_flagged_reason`, lu par l'admin — au lieu d'être enregistré.
  # Un résultat correct efface le motif d'un rejet précédent.
  def geocode_and_guard
    geocode
    if latitude.present? && longitude.present? && far_from_nancy?
      distance = distance_to_nancy_km.round(1)
      self.geocoding_flagged_reason =
        "résultat à #{distance} km de Nancy (#{latitude}, #{longitude}), rejeté"
      Rails.logger.warn("[geocode_and_guard] #{self.class.name} ##{id || '(nouveau)'} : #{geocoding_flagged_reason}")
      self.latitude = nil
      self.longitude = nil
    elsif latitude.present? && longitude.present?
      self.geocoding_flagged_reason = nil
    end
  end
end
