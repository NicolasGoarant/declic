# frozen_string_literal: true

module Admin
  # Galerie : fiches en ligne et candidats de la veille, vus ensemble. Même protection que /admin/veille
  # (hérite de Admin::Veille::BaseController : Basic auth, layout avec Turbo). Les actions des cartes
  # pointent vers celles de Admin::Veille::CandidatesController ; les actions groupées (`actions`) rejouent
  # les mêmes règles sur la sélection.
  class GalerieController < Admin::Veille::BaseController
    def index
      @galerie = ::Galerie.new(params)
      @plafond = ::Veille::Cout.etat_du_mois
    end

    # Publier / Écarter / Classer sur les cartes cochées (formulaire standard, sans JavaScript). Seuls les candidats
    # sont concernés. Chaque élément écarté de l'action est compté avec sa raison dans le message.
    def actions
      cles = Array(params[:cles]).grep(/\Acandidate_\d+\z/)
      autres = Array(params[:cles]).size - cles.size
      action = params[:action_groupee].to_s
      return redirect_to(retour_galerie, alert: "Coche d'abord au moins une carte.", status: :see_other) if Array(params[:cles]).empty?

      candidats = ::Veille::Candidate.where(id: cles.map { |c| c.delete_prefix("candidate_").to_i }).to_a
      bilan = { faits: 0, ignores: Hash.new(0) }
      bilan[:ignores]["fiches déjà en ligne ou retirées"] += autres if autres.positive?

      case action
      when "publier"  then candidats.each { |c| publier(c, bilan) }
      when "ecarter"  then candidats.each { |c| ecarter(c, bilan) }
      when /\Aclasser:(belle_histoire|opportunite)(?::(\w+))?\z/ then candidats.each { |c| classer(c, Regexp.last_match(1), Regexp.last_match(2), bilan) }
      else return redirect_to(retour_galerie, alert: "Action groupée inconnue.", status: :see_other)
      end

      redirect_to retour_galerie, status: :see_other, notice: message(action, bilan)
    end

    private

    def retour_galerie = retour_admin(admin_galerie_path)

    def publier(candidat, bilan)
      return bilan[:ignores]["non classées"] += 1 if candidat.item_type.blank?
      return bilan[:ignores]["pas encore triées"] += 1 if candidat.pending? && !candidat.enriched?
      return bilan[:ignores]["déjà traitées"] += 1 unless candidat.pending? || candidat.a_verifier? || candidat.retenu?
      return bilan[:ignores]["récits à relire un par un"] += 1 if candidat.histoire?

      ::Veille::Validation.new(candidat).call
      bilan[:faits] += 1
    rescue ::Veille::Validation::Incomplet, ActiveRecord::RecordInvalid
      bilan[:ignores]["incomplètes"] += 1
    end

    def ecarter(candidat, bilan)
      return bilan[:ignores]["déjà publiées"] += 1 if candidat.publie?

      candidat.update!(status: "ecarte")
      bilan[:faits] += 1
    end

    def classer(candidat, type, categorie, bilan)
      return bilan[:ignores]["déjà publiées"] += 1 if candidat.publie?

      candidat.classer(type, categorie).save!
      bilan[:faits] += 1
    rescue ActiveRecord::RecordInvalid
      bilan[:ignores]["classement refusé"] += 1
    end

    # « 5 publiées, 2 ignorées : non classées » ; plusieurs raisons : « 3 ignorées : 2 non classées, 1 incomplète ».
    def message(action, bilan)
      verbe = action == "publier" ? "publiée" : (action == "ecarter" ? "écartée" : "classée")
      faits = bilan[:faits]
      texte = "#{faits} #{verbe}#{'s' if faits > 1}"
      ignores = bilan[:ignores].reject { |_, n| n.zero? }
      return texte if ignores.empty?

      total = ignores.values.sum
      raisons = ignores.size == 1 ? ignores.keys.first : ignores.map { |r, n| "#{n} #{r}" }.join(", ")
      "#{texte}, #{total} ignorée#{'s' if total > 1} : #{raisons}"
    end
  end
end
