# frozen_string_literal: true

module Veille
  # Annuaire des 19 communes du Grand Nancy hors Nancy (config/veille/communes_grand_nancy.yml) :
  # site, flux RSS, mentions légales, pages sociales. Dit quelles communes le connecteur
  # Connectors::Communes peut lire (flux actif, réutilisation non interdite) et lesquelles
  # restent à la lecture humaine (/admin/veille/communes).
  module AnnuaireCommunes
    FICHIER = Rails.root.join("config/veille/communes_grand_nancy.yml")

    Commune = Struct.new(:nom, :site, :rss, :flux_actif, :derniere_publication, :mentions_legales,
                         :reutilisation, :reutilisation_note, :facebook, :instagram, :remarque,
                         keyword_init: true) do
      # Le connecteur lit cette commune : flux actif et aucune interdiction de réutilisation.
      def automatisable? = rss.present? && flux_actif && reutilisation != "restreinte"

      def reutilisation_restreinte? = reutilisation == "restreinte"
    end

    module_function

    def toutes(fichier: FICHIER)
      donnees = YAML.safe_load_file(fichier, permitted_classes: [Date], symbolize_names: true)
      donnees.fetch(:communes).map { |c| Commune.new(**c.slice(*Commune.members)) }
    end

    def automatisables(fichier: FICHIER) = toutes(fichier: fichier).select(&:automatisable?)

    # Lues à la main : toutes les autres.
    def manuelles(fichier: FICHIER) = toutes(fichier: fichier).reject(&:automatisable?)

    def par_nom(nom, fichier: FICHIER)
      cle = GrandNancy.canonique(nom)
      toutes(fichier: fichier).find { |c| c.nom == cle }
    end
  end
end
