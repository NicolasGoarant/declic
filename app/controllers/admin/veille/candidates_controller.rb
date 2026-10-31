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

      def show; end

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

      # Rédige (ou rédige à nouveau) le récit. Sans texte collé : à partir du résumé et du
      # chapeau ; avec : à partir de l'article. Tourne dans la requête web, en synchrone :
      # profil :web du Brouillon (budget de 30 s d'Heroku). Le brouillon est enregistré,
      # contrôlé et relu ici ; aucune fiche n'est créée (c'est le rôle de « Valider »).
      def rediger
        colle = params[:full_text].to_s.strip
        @candidate.update!(full_text: colle) if colle.present?
        ::Veille::Redaction::Brouillon.new(profil: :web).draft(@candidate, texte: colle.presence || @candidate.full_text.presence)
        repondre_brouillon
      rescue ArgumentError, ::Veille::AiPass::ParseError, AnthropicClient::Error, ::Veille::Plafond::Depasse => e
        @error = message_pour(e)
        Rails.logger.error("[Veille] rédaction candidat ##{@candidate.id} : #{e.class} #{e.message}")
        repondre_brouillon(status: :unprocessable_entity)
      end

      # Récit corrigé à la main : les mentions (source, accord) sont reposées par le code, puis les
      # contrôles repassent sur le texte corrigé.
      def enregistrer_brouillon
        recit = params[:recit].to_s.strip
        if recit.blank?
          @error = "Le récit est vide."
          return repondre_brouillon(status: :unprocessable_entity)
        end

        source = ::Veille::Redaction::Brouillon.source_pour(@candidate, texte: @candidate.full_text.presence)
        controles = ::Veille::Redaction::Controles.verifier(recit, source: source, manques: @candidate.draft_manques)
        @candidate.update!(draft_body: ::Veille::Redaction::Brouillon.recomposer(@candidate, recit),
                           draft_controles: controles.as_json, draft_status: controles.bloque? ? "a_verifier" : "redige")
        @info = controles.bloque? ? "Récit enregistré, mais des points bloquants restent à corriger." : "Récit enregistré, contrôles passés."
        repondre_brouillon
      end

      # Accord de la personne racontée : daté ici, reporté dans la mention du récit, puis dans la fiche
      # à sa création. Sans lui, la fiche ne peut pas être mise en ligne.
      def accord
        obtenu = ActiveModel::Type::Boolean.new.cast(params[:obtenu])
        @candidate.accord_obtenu_at = obtenu ? (@candidate.accord_obtenu_at || Time.current) : nil
        if @candidate.draft_body.present?
          recit = ::Veille::Redaction::Brouillon.sans_mentions(@candidate.draft_body)
          @candidate.draft_body = ::Veille::Redaction::Brouillon.recomposer(@candidate, recit)
        end
        @candidate.save!
        @info = obtenu ? "Accord de la personne enregistré." : "Accord de la personne retiré."
        repondre_brouillon
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

      # Le panneau du brouillon se met à jour sans recharger la page (Turbo Stream).
      def repondre_brouillon(status: :ok)
        respond_to do |format|
          format.turbo_stream { render :rediger, status: status }
          format.html do
            flash[status == :ok ? :notice : :alert] = @error || @info || "Récit à jour."
            redirect_to admin_veille_candidate_path(@candidate)
          end
        end
      end

      def message_pour(error)
        case error
        when ArgumentError
          "Rien à rédiger : colle le texte de l'article dans la zone de droite (ce candidat n'a pas de résumé)."
        when ::Veille::Plafond::Depasse
          error.message
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
