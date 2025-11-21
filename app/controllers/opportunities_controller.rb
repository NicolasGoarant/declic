# app/controllers/opportunities_controller.rb
# frozen_string_literal: true

class OpportunitiesController < ApplicationController
  # GET /opportunities
  def index
    @opportunities =
      Opportunity.active
                 .order(Arel.sql("COALESCE(starts_at, created_at) DESC"))
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

  # POST /opportunities
  #
  # - bouton "Prévisualiser ma fiche" -> params[:preview] présent
  # - bouton "Valider et envoyer à Déclic" -> pas de :preview -> on enregistre + on envoie le mail
def create
  @opportunity = Opportunity.new(opportunity_params)

  if @opportunity.save
    OpportunityProposalMailer.with(opportunity: @opportunity)
                             .proposal_email
                             .deliver_later

    redirect_to @opportunity,
      notice: "Merci ! Votre proposition a bien été envoyée à l’équipe Déclic. Elle sera relue avant publication."
  else
    render :new, status: :unprocessable_entity
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
      # Mail de confirmation à Nicolas
      OpportunityProposalMailer.with(opportunity: @opportunity)
                               .proposal_email
                               .deliver_later

      redirect_to @opportunity,
                  notice: "Merci ! Votre proposition a bien été envoyée à l’équipe Déclic. Elle sera relue avant publication."
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
      :image_url,
      :source_url,
      :tags,
      :website,
      :address,
      :postcode,
      :city,
      :contact_email,
      :contact_phone,
      photos: []
    )
  end
end
