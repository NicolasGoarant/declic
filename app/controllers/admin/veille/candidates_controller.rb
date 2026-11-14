# frozen_string_literal: true

module Admin
  module Veille
    # Attention au double sens de « Veille » ici : dans ce fichier, la
    # constante Veille désigne Admin::Veille. Les modèles et services du
    # chantier se référencent donc toujours en absolu : ::Veille::Candidate.
    class CandidatesController < BaseController
      before_action :set_candidate, except: :index

      # La liste de relecture a fusionné dans la galerie : /admin/veille y renvoie, avec le préréglage « À relire »
      # (ou l'équivalent du statut demandé). Les écrans d'un candidat (show, apercu…) ne changent pas d'adresse.
      def index
        statut = { "pending" => "a_relire", "a_verifier" => "a_verifier", "retenu" => "propose", "ecarte" => "ecarte" }.fetch(params[:status].to_s, "a_relire")
        categorie = Categorie.trouver(params[:categorie])&.libelle if params[:categorie].present? && params[:type] != "belle_histoire"
        filtres = { statut: statut, tri: "score", type: params[:type].presence_in(::Galerie::TYPES.keys), categorie: categorie,
                    depuis: params[:depuis].presence, a_localiser: params[:a_localiser].presence }.compact
        redirect_to admin_galerie_path(filtres)
      end

      def show
        @voisins = voisins_dans_la_liste
      end

      # Aperçu de ce que « Valider » publierait : les VRAIES vues publiques (opportunities/show,
      # stories/show, layout fiche) rendues sur la fiche que construit Validation, sans rien
      # enregistrer. Affiché dans une iframe de l'écran du candidat.
      def apercu
        return render(plain: "Aperçu indisponible : #{@candidate.manque_pour_apercu}.", status: :unprocessable_entity) if @candidate.manque_pour_apercu

        fiche = ::Veille::Validation.new(@candidate).apercu
        if fiche.is_a?(Story)
          @story = fiche
          @opportunites = []
          @autres_histoires = Story.none
          @tuiles = DioramaTuiles.new if fiche.latitude.present?
          render template: "stories/show", layout: "fiche"
        else
          @opportunity = fiche
          @similaires = Opportunity.none
          @tuiles = DioramaTuiles.new if fiche.latitude.present?
          render template: "opportunities/show", layout: "fiche"
        end
      end

      def retenir = trancher("retenu", "Candidat retenu.")

      def ecarter = trancher("ecarte", "Candidat écarté.")

      def a_verifier = trancher("a_verifier", "Marqué à vérifier.")

      # « Valider » : crée la fiche (Opportunity ou Story) et la met en ligne.
      def valider
        suite = suite_apres_decision
        fiche = ::Veille::Validation.new(@candidate).call
        return redirect_to(suite, status: :see_other, **avis_publication(fiche)) if suite

        redirect_back fallback_location: admin_galerie_path, **avis_publication(fiche)
      rescue ::Veille::Validation::Incomplet => e
        redirect_back fallback_location: admin_galerie_path, alert: e.message
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

      # Article de presse retenu à la main (l'IA ne l'a pas classé) ou élément à localiser : la
      # commune et le résumé que demande « Valider » sont saisis ici. Un élément à localiser a déjà
      # été classé par l'IA : la saisie de sa commune le publie, sans autre geste. La presse reste
      # sur son propre circuit (texte collé, récit, accord, puis « Valider »).
      def completer
        @candidate.classer(params[:item_type], params[:declic_category]) if params[:item_type].present?
        return localiser if @candidate.a_localiser? && params[:commune].to_s.strip.present?

        @candidate.update!(params.permit(:title, :schedule_text, :commune, :adresse, :summary).to_h.compact)
        redirect_to admin_veille_candidate_path(@candidate, retour: retour_admin(nil)), status: :see_other, notice: "Modifications enregistrées."
      end

      # Mini-formulaire des cartes « À classer » (et bloc Classement de l'écran du candidat) : type, et catégorie pour
      # une opportunité. Le classement posé à la main n'est plus modifié par le tri IA.
      def classer
        if params[:item_type] == "opportunite" && params[:declic_category].blank?
          return redirect_back fallback_location: admin_galerie_path, alert: "Choisis une catégorie pour une opportunité."
        end

        @candidate.classer(params[:item_type], params[:declic_category]).save!
        redirect_back fallback_location: admin_galerie_path, status: :see_other, notice: "Classé : #{@candidate.title.presence || 'élément'}."
      rescue ActiveRecord::RecordInvalid => e
        redirect_back fallback_location: admin_galerie_path, alert: "Classement refusé : #{e.record.errors.full_messages.to_sentence}"
      end

      private

      # Une faute de frappe ne doit pas mettre en ligne une fiche mal située : même périmètre
      # que la collecte (Veille::Territoire). Rien n'est enregistré si la commune est refusée.
      def localiser
        saisie = params[:commune].to_s.strip
        unless ::Veille::Territoire.admis?(saisie, @candidate.item_type)
          return redirect_to admin_veille_candidate_path(@candidate), status: :see_other,
                             alert: "« #{saisie} » n'est pas une commune du périmètre : rien n'a été enregistré ni publié."
        end

        @candidate.update!(params.permit(:title, :schedule_text, :summary, :adresse).to_h.compact.merge(commune: ::Veille::Territoire.canonique(saisie)))
        fiche = ::Veille::Validation.new(@candidate).call
        redirect_to admin_veille_candidate_path(@candidate), status: :see_other, **avis_publication(fiche)
      rescue ::Veille::Validation::Incomplet => e
        redirect_to admin_veille_candidate_path(@candidate), status: :see_other, alert: "Commune enregistrée, pas encore de publication. #{e.message}"
      rescue ActiveRecord::RecordInvalid => e
        redirect_to admin_veille_candidate_path(@candidate), status: :see_other,
                    alert: "Commune enregistrée, publication impossible : #{e.record.errors.full_messages.to_sentence}"
      end

      # Une fiche sans coordonnées est en ligne mais absente de la carte : autant le dire tout de suite.
      # Le lien voyage à part du message : le titre vient de la source, le message reste échappé.
      def avis_publication(fiche)
        avis = "En ligne : #{fiche.title}"
        avis = "#{avis}. Position introuvable : pas de pin sur la carte tant qu'elle n'est pas corrigée dans la fiche." if fiche.latitude.blank?
        { notice: avis, flash: { lien_fiche: polymorphic_path(fiche) } }
      end

      def date_filtre(valeur)
        Date.iso8601(valeur.to_s) if valeur.present?
      rescue Date::Error
        nil
      end

      # Candidats de la liste filtrée d'où l'on vient (paramètre `retour` : une adresse de la galerie), dans son
      # ordre : le candidat courant, ses voisins, et la page de la galerie où se trouve chacun.
      def voisins_dans_la_liste
        retour = retour_admin(nil) or return nil
        requete = Rack::Utils.parse_nested_query(URI.parse(retour).query.to_s)
        galerie = ::Galerie.new(requete)
        cartes = galerie.cartes.select(&:candidat?)
        i = cartes.index { |c| c.record.id == @candidate.id } or return nil

        lien = lambda do |carte|
          next unless carte
          page = galerie.page_de(carte.cle)
          admin_veille_candidate_path(carte.record, retour: admin_galerie_path(requete.merge("page" => page.to_s)))
        end
        { position: i + 1, total: cartes.size, precedent: (lien.call(cartes[i - 1]) if i.positive?), suivant: lien.call(cartes[i + 1]),
          liste: retour }
      end

      # Après Valider ou Écarter depuis l'écran du candidat (`enchainer`) : le candidat suivant de la liste, ou la
      # galerie (mêmes filtres, même page) en fin de liste. nil hors enchaînement : les appelants gardent leur retour.
      def suite_apres_decision
        return unless params[:enchainer].present?

        voisins_dans_la_liste&.dig(:suivant) || retour_admin(admin_galerie_path)
      end

      def set_candidate
        @candidate = ::Veille::Candidate.find(params[:id])
      end

      def trancher(status, notice)
        suite = suite_apres_decision
        @candidate.update!(status: status)
        @counts = compteurs
        return redirect_to(suite, notice: notice, status: :see_other) if suite

        respond_to do |format|
          # La ligne disparaît de la file sans rechargement.
          format.turbo_stream
          format.html { redirect_back fallback_location: admin_galerie_path, notice: notice, status: :see_other }
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
          a_localiser: ::Veille::Candidate.a_localiser.count,
          retenu:  ::Veille::Candidate.retenu.count,
          ecarte:  ::Veille::Candidate.ecarte.count,
          publie:  ::Veille::Candidate.publie.count,
          non_tries: ::Veille::Candidate.a_enrichir.count
        }
      end
    end
  end
end
