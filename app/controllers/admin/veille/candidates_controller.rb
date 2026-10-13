# frozen_string_literal: true

module Admin
  module Veille
    # Attention au double sens de « Veille » ici : dans ce fichier, la
    # constante Veille désigne Admin::Veille. Les modèles et services du
    # chantier se référencent donc toujours en absolu : ::Veille::Candidate.
    class CandidatesController < BaseController
      before_action :set_candidate, except: :index

      # La file de tri : par défaut les candidats en attente, meilleur score
      # d'abord. Les autres statuts sont accessibles en onglets — sans quoi
      # un candidat retenu deviendrait injoignable, la file ne listant que
      # les pending.
      def index
        @status = params[:status].presence_in(::Veille::Candidate::STATUSES) || "pending"
        @filtres = params.permit(:type, :categorie, :origine, :depuis).to_h.symbolize_keys

        base =
          if @status == "pending"
            ::Veille::Candidate.file_de_tri
          else
            ::Veille::Candidate.where(status: @status).order(updated_at: :desc)
          end
        @candidates = base.par_type(@filtres[:type]).par_categorie(@filtres[:categorie])
                          .par_origine(@filtres[:origine]).collectes_depuis(date_filtre(@filtres[:depuis]))
                          .includes(:source, :story, :opportunity)

        @counts = compteurs
      end

      def show
        @draft = nil
      end

      def retenir = trancher("retenu", "Candidat retenu.")

      def ecarter = trancher("ecarte", "Candidat écarté.")

      def a_verifier = trancher("a_verifier", "Marqué à vérifier.")

      # « Valider » : crée le brouillon (Opportunity ou Story, inactif) à partir du
      # résumé reformulé. Aucune publication : la mise en ligne se fait ensuite
      # depuis l'admin des fiches.
      def valider
        fiche = ::Veille::Validation.new(@candidate).call
        redirect_back fallback_location: admin_veille_root_path,
                      notice: "Brouillon créé, hors ligne : #{fiche.title}"
      rescue ::Veille::Validation::Incomplet => e
        redirect_back fallback_location: admin_veille_root_path, alert: e.message
      rescue ActiveRecord::RecordInvalid => e
        redirect_back fallback_location: admin_veille_root_path,
                      alert: "Création impossible : #{e.record.errors.full_messages.to_sentence}"
      end

      # Passe B. Tourne dans la requête web, en synchrone : voir
      # Veille::Drafter pour le budget de temps sous les 30 s d'Heroku.
      def rediger
        @candidate.update!(full_text: params[:full_text])
        @draft = ::Veille::Drafter.new.draft(@candidate)
        render :rediger
      rescue ArgumentError, ::Veille::AiPass::ParseError, AnthropicClient::Error => e
        @error = message_pour(e)
        Rails.logger.error("[Veille] rédaction candidat ##{@candidate.id} : #{e.class} #{e.message}")
        render :rediger, status: :unprocessable_entity
      end

      # Crée la fiche en brouillon (is_active=false via Story). Le callback
      # Story#purge_veille_candidate_full_text efface full_text au passage.
      def publier
        story = build_story

        if story.save
          @candidate.update!(status: "publie")
          redirect_to admin_veille_candidates_path,
                      notice: "Fiche créée en brouillon : #{story.title}"
        else
          @draft = draft_params.to_h
          @error = "Création impossible : #{story.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
      end

      private

      def date_filtre(valeur)
        Date.iso8601(valeur.to_s) if valeur.present?
      rescue Date::Error
        nil
      end

      def set_candidate
        @candidate = ::Veille::Candidate.find(params[:id])
      end

      def trancher(status, notice)
        @candidate.update!(status: status)
        @counts = compteurs

        respond_to do |format|
          # La ligne disparaît de la file sans rechargement.
          format.turbo_stream
          format.html { redirect_to admin_veille_candidates_path, notice: notice }
        end
      end

      def build_story
        d = draft_params

        ::Story.new(
          title:            d[:titre].presence || @candidate.title,
          chapo:            d[:resume],
          body:             corps_initial(d),
          location:         d[:commune].presence,
          tags:             d[:theme].presence,
          happened_on:      @candidate.published_on,
          source_url:       @candidate.url,
          source_name:      @candidate.source_label,
          veille_candidate: @candidate
          # is_active reste false : Story#set_default_active.
        )
      end

      # Le résumé sert d'amorce au récit, que l'éditeur développera avant
      # d'activer la fiche. Le lien vers la source d'origine est posé dès
      # maintenant pour ne pas risquer de l'oublier.
      def corps_initial(d)
        [d[:resume], "[Source originale](#{@candidate.url})"].compact_blank.join("\n\n")
      end

      def draft_params
        params.fetch(:draft, {}).permit(:titre, :personne, :commune, :resume, :theme)
      end

      def message_pour(error)
        case error
        when ArgumentError
          "Colle d'abord le texte de l'article dans la zone de gauche."
        when AnthropicClient::ConnectionError
          "L'API Anthropic n'a pas répondu à temps. Réessaie."
        when AnthropicClient::RateLimitError
          "Limite de débit Anthropic atteinte. Attends quelques instants."
        when AnthropicClient::AuthenticationError
          "Clé ANTHROPIC_API_KEY absente ou invalide."
        else
          "Le modèle a renvoyé une réponse inexploitable. Réessaie."
        end
      end

      def compteurs
        {
          pending: ::Veille::Candidate.pending.count,
          a_verifier: ::Veille::Candidate.a_verifier.count,
          retenu:  ::Veille::Candidate.retenu.count,
          ecarte:  ::Veille::Candidate.ecarte.count,
          publie:  ::Veille::Candidate.publie.count
        }
      end
    end
  end
end
