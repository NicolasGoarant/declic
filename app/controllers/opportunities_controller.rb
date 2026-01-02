# app/controllers/opportunities_controller.rb
# frozen_string_literal: true

class OpportunitiesController < ApplicationController
  # GET /opportunities
  def index
    # 1. Commence avec le scope de base (actives)
    opportunities = Opportunity.active

    # 2. Ajoute un filtre par catégorie si le paramètre est présent dans l'URL
    if params[:category].present?
      opportunities = opportunities.where(category: params[:category])
    end

    # 3. Applique l'ordre et la limite
    @opportunities =
      opportunities.order(Arel.sql("COALESCE(starts_at, created_at) DESC"))
                   .limit(1000)

    respond_to do |format|
      format.html
      format.json do
        render json: @opportunities.as_json(
          only: %i[
            id slug title description category organization location
            time_commitment latitude longitude image_url
          ]
        )
      end
    end
  end

  # GET /opportunities/:id
  def show
    @opportunity = Opportunity.friendly.find(params[:id])
  end

  # GET /opportunities/new
  def new
    @opportunity = Opportunity.new
  end

  # Action pour la page de remerciement (Route: get :merci dans routes.rb)
  def merci
    # Cette action rend simplement la vue app/views/opportunities/merci.html.erb
  end

  # POST /opportunities
  def create
    @opportunity = Opportunity.new(opportunity_params)

    if params[:preview]
      handle_preview
    else
      handle_final_submit
    end
  end

  private

  # ----- Flux "prévisualiser" -----
  def handle_preview
    @preview = @opportunity.valid?
    status   = @preview ? :ok : :unprocessable_entity
    render :new, status: status
  end

  # ----- Flux "valider et envoyer à Déclic" -----
  def handle_final_submit
    if @opportunity.save
      # Envoi du mail à l'équipe
      OpportunityProposalMailer.with(opportunity: @opportunity)
                               .proposal_email
                               .deliver_later

      # REDIRECTION : Vers la page "Merci" au lieu de la fiche directe
      redirect_to merci_opportunities_path
    else
      flash.now[:alert] = @opportunity.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # ----- Strong params -----
  def opportunity_params
    params.require(:opportunity).permit(
      :title,
      :description,
      :category,
      :organization,
      :location,
      :time_commitment,
      :starts_at,
      :ends_at,
      :latitude,
      :longitude,
      :is_active,
      :image,           # Image hero
      :image_url,
      :gallery_image_1,
      :gallery_image_2,
      :gallery_image_3,
      :source_url,
      :tags,
      :website,
      :address,
      :postcode,
      :city,
      :contact_email,
      :contact_phone,
      photos: []        # Pour l'upload multiple que vous avez ajouté
    )
  end
end
