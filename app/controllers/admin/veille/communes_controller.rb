# frozen_string_literal: true

module Admin
  module Veille
    # Communes du Grand Nancy lues à la main : celles dont le site n'offre pas de flux lisible, ou
    # dont les mentions légales interdisent la réutilisation (voir Veille::AnnuaireCommunes).
    # La page ne fait que des liens vers leur site et leurs pages sociales : aucun appel
    # automatisé, aucun stockage. « Retenir » est le seul geste qui crée un candidat : il ne
    # porte que le titre, le lien et la commune, et les passes automatiques l'ignorent
    # (Veille::Candidate.hors_presse), comme pour la presse.
    class CommunesController < BaseController
      def index
        @communes = ::Veille::AnnuaireCommunes.manuelles
        @automatiques = ::Veille::AnnuaireCommunes.automatisables
      end

      def retenir
        titre   = params[:titre].to_s.squish
        url     = params[:url].to_s.strip
        commune = ::Veille::AnnuaireCommunes.par_nom(params[:commune])
        unless titre.present? && lien_http?(url) && commune
          return redirect_to admin_veille_communes_path, status: :see_other,
                             alert: "Titre, lien (http ou https) et commune du Grand Nancy sont requis : rien n'a été retenu."
        end

        candidat = ::Veille::Candidate.find_or_create_by!(url: url) do |c|
          c.assign_attributes(title: titre.slice(0, 250), origin: "commune_manuel", item_type: "opportunite",
                              status: "retenu", reliability: "moyenne", commune: commune.nom, fetched_at: Time.current)
        end
        redirect_to admin_veille_candidate_path(candidat), status: :see_other,
                    notice: "Annonce retenue (#{commune.nom}) : complète la fiche ou colle son texte."
      end

      private

      def lien_http?(url)
        uri = URI.parse(url)
        uri.is_a?(URI::HTTP) && uri.host.present?
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
