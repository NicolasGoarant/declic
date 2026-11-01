# frozen_string_literal: true

module Admin
  module Veille
    # Veille presse manuelle : titres et liens lus à l'affichage, sans stockage ni
    # IA. « Retenir » est le seul moyen de faire entrer un article en base : il crée
    # un candidat qui ne porte que le titre et le lien, et que les passes
    # automatiques ignorent (Veille::Candidate.hors_presse). « Écarter » ne garde que
    # l'URL de l'article (Veille::PresseEcartee), pour ne plus le proposer.
    class PresseController < BaseController
      def index
        lecture = ::Veille::Connectors::Presse.new.lister
        ecartees = ::Veille::PresseEcartee.where(url: lecture.liens.map(&:url)).pluck(:url).to_set
        @lecture = ::Veille::Connectors::Presse::Lecture.new(liens: lecture.liens.reject { |l| ecartees.include?(l.url) },
                                                             erreurs: lecture.erreurs)
      end

      def ecarter
        url = params[:url].to_s.strip
        unless ::Veille::Connectors::Presse.lien_autorise?(url)
          return redirect_to admin_veille_presse_path, alert: "Ce lien ne provient pas d'un flux de la veille presse."
        end

        ::Veille::PresseEcartee.find_or_create_by!(url: url)
        redirect_to admin_veille_presse_path, status: :see_other, notice: "Article écarté : il ne sera plus proposé."
      end

      def retenir
        url = params[:url].to_s.strip
        titre = params[:titre].to_s.strip
        unless titre.present? && ::Veille::Connectors::Presse.lien_autorise?(url)
          return redirect_to admin_veille_presse_path, alert: "Ce lien ne provient pas d'un flux de la veille presse."
        end

        candidat = ::Veille::Candidate.find_or_create_by!(url: url) do |c|
          c.assign_attributes(title: titre, origin: "presse", item_type: "belle_histoire", status: "retenu",
                              reliability: "moyenne", fetched_at: Time.current, published_on: date_publication)
        end
        redirect_to admin_veille_candidate_path(candidat), status: :see_other,
                    notice: "Article retenu : colle son texte pour lancer la rédaction."
      end

      private

      def date_publication
        Date.iso8601(params[:publie_le].to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
