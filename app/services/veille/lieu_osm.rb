# frozen_string_literal: true

require "json"

module Veille
  # Position d'un LIEU NOMMÉ (« Musée des Beaux-Arts », « Centre social Beauregard ») que l'API Adresse
  # ne connaît pas : elle ne répertorie que des adresses postales (« Musée des Beaux-Arts Nancy » y donne
  # une rue de Bordeaux). On interroge donc Nominatim (OpenStreetMap, déjà utilisé par les fiches),
  # borné à l'emprise du Grand Nancy.
  #
  # Ne lève jamais : lieu vide, introuvable, hors de la commune, service en panne -> nil.
  module LieuOsm
    URL = "https://nominatim.openstreetmap.org/search"

    class << self
      # Remplaçable en test : doit répondre à `get(url, headers:, robots:)` et rendre le corps JSON.
      attr_writer :client

      def client = (@client ||= Veille::Http.new)

      def localiser(lieu, commune)
        lieu    = lieu.to_s.squish
        commune = commune.to_s.squish
        return nil if lieu.blank? || commune.blank?

        v = ::NancyGeocodable::VIEWBOX
        params = { format: "jsonv2", limit: 1, addressdetails: 1, countrycodes: "fr", bounded: 1,
                   viewbox: [v[:min_lon], v[:max_lat], v[:max_lon], v[:min_lat]].join(","), q: "#{lieu}, #{commune}" }
        resultat = JSON.parse(client.get("#{URL}?#{URI.encode_www_form(params)}", robots: false)).first
        retenir(resultat, commune)
      rescue Veille::Http::Error, JSON::ParserError => e
        Rails.logger.warn("[LieuOsm] #{lieu.inspect}, #{commune} : #{e.class} #{e.message}")
        nil
      end

      private

      def retenir(resultat, commune)
        return nil unless resultat

        adresse = resultat["address"].to_h
        ville = adresse.values_at("city", "town", "village", "municipality").compact.first
        # Comme pour la BAN : le lieu doit être dans la commune de la fiche, pas dans une homonyme voisine.
        return nil unless Veille::Text.normalize(ville) == Veille::Text.normalize(commune)

        lat = Float(resultat["lat"], exception: false)
        lon = Float(resultat["lon"], exception: false)
        return nil unless lat && lon

        AdresseBan::Resultat.new(latitude: lat, longitude: lon, libelle: resultat["display_name"])
      end
    end
  end
end
