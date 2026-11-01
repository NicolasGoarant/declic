# frozen_string_literal: true

require "json"

module Veille
  # Géocode une adresse précise avec l'API Adresse du gouvernement (Base Adresse
  # Nationale, gratuite, sans clé). Sert à poser le repère d'une fiche sur son
  # adresse plutôt qu'au centre de sa commune.
  #
  # Ne lève jamais : adresse vide, introuvable, trop approximative, hors de la
  # commune ou de la zone, API en panne -> nil, et l'appelant garde la commune.
  module AdresseBan
    URL         = "https://api-adresse.data.gouv.fr/search/"
    SCORE_MIN   = 0.6
    TYPES       = %w[housenumber street locality].freeze # jamais « municipality » : ce serait le centre-ville
    Resultat    = Struct.new(:latitude, :longitude, :libelle, keyword_init: true)

    class << self
      # Remplaçable en test : doit répondre à `get(url, robots:)` et rendre le corps JSON.
      attr_writer :client

      def client = (@client ||= Veille::Http.new)

      def localiser(adresse, commune)
        adresse = adresse.to_s.squish
        commune = commune.to_s.squish
        return nil if adresse.blank? || commune.blank?

        url = "#{URL}?#{URI.encode_www_form(q: "#{adresse} #{commune}", limit: 1, autocomplete: 0)}"
        propriete = JSON.parse(client.get(url, robots: false)).dig("features", 0)
        retenir(propriete, commune)
      rescue Veille::Http::Error, JSON::ParserError => e
        Rails.logger.warn("[AdresseBan] #{adresse.inspect}, #{commune} : #{e.class} #{e.message}")
        nil
      end

      private

      def retenir(feature, commune)
        return nil unless feature

        props = feature["properties"].to_h
        lon, lat = feature.dig("geometry", "coordinates")
        return nil if lat.nil? || lon.nil?
        return nil unless props["score"].to_f >= SCORE_MIN && TYPES.include?(props["type"])
        # L'adresse trouvée doit être dans la commune de la fiche, pas dans une homonyme voisine.
        return nil unless Veille::Text.normalize(props["city"]) == Veille::Text.normalize(commune)

        Resultat.new(latitude: lat.to_f, longitude: lon.to_f, libelle: props["label"])
      end
    end
  end
end
