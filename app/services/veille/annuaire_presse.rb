# frozen_string_literal: true

module Veille
  # Registre des flux de presse locale (config/veille/flux_presse.yml). Dit lesquels
  # Connectors::FluxPresse peut lire : flux déclaré et conditions d'utilisation qui
  # ne s'opposent pas à la fouille de textes.
  module AnnuairePresse
    FICHIER = Rails.root.join("config/veille/flux_presse.yml")

    Source = Struct.new(:nom, :origine, :flux, :hotes, :reutilisation, :note, :categories_exclues, keyword_init: true) do
      def automatisable? = flux.any? && reutilisation == "non_opposee"

      def lien_autorise?(url)
        host = URI.parse(url.to_s).host
        host.present? && hotes.include?(host)
      rescue URI::InvalidURIError
        false
      end

      def categorie_exclue?(categories)
        exclues = Array(categories_exclues).map { |c| Veille::Text.normalize(c) }
        Array(categories).any? { |c| exclues.include?(Veille::Text.normalize(c)) }
      end
    end

    module_function

    def toutes(fichier: FICHIER)
      YAML.safe_load_file(fichier, symbolize_names: true).fetch(:sources).map do |s|
        Source.new(**s.slice(*Source.members).reverse_merge(flux: [], categories_exclues: []))
      end
    end

    def automatisables(fichier: FICHIER) = toutes(fichier: fichier).select(&:automatisable?)

    def ecartees(fichier: FICHIER) = toutes(fichier: fichier).reject(&:automatisable?)
  end
end
