# frozen_string_literal: true

module Admin
  module Veille
    # Étiquetage pour calibrer le prompt : espace séparé de la file de relecture. La décision de
    # la v4 n'est pas affichée, pour ne pas orienter l'avis ; elle se lit avec rake veille:etiquetage.
    class EtiquetageController < BaseController
      def index
        @cas = ::Veille::Etiquetage.cas
        @etiquettes = ::Veille::Etiquette.all.index_by(&:ref)
      end

      # Un bouton enregistre l'avis et le commentaire ; quitter le champ, le commentaire seul.
      def update
        @cas = ::Veille::Etiquetage.trouver(params[:ref]) or return head(:not_found)

        @etiquette = ::Veille::Etiquette.find_or_initialize_by(ref: @cas.ref)
        @etiquette.avis = params[:avis] if params[:avis].present?
        @etiquette.commentaire = params[:commentaire].to_s.strip.presence if params.key?(:commentaire)
        return head(:unprocessable_entity) unless @etiquette.save

        @faits = ::Veille::Etiquette.where.not(avis: nil).count
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to admin_veille_etiquetage_path(anchor: @cas.ref), status: :see_other }
        end
      rescue ActiveRecord::RecordNotUnique
        retry # deux clics simultanés sur un cas encore vierge
      end
    end
  end
end
