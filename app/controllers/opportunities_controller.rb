# frozen_string_literal: true

class OpportunitiesController < ApplicationController
  def index
    @opportunities = Opportunity.active.order(created_at: :desc).limit(100)
  end

  def show
    @opportunity = Opportunity.friendly.find(params[:id])
  end

  def new
    @opportunity = Opportunity.new
  end

  def merci
    # Rend la vue merci.html.erb
  end

  def create
    @opportunity = Opportunity.new(opportunity_params)

    if params[:preview]
      handle_preview
    else
      handle_final_submit
    end
  end

  private

  def handle_preview
    @preview = @opportunity.valid?
    render :new, status: @preview ? :ok : :unprocessable_entity
  end

  def handle_final_submit
    if @opportunity.save
      # Envoi immédiat à Mailtrap (ou en queue selon config)
      OpportunityProposalMailer.with(opportunity: @opportunity).proposal_email.deliver_later
      redirect_to merci_opportunities_path
    else
      flash.now[:alert] = "Veuillez corriger les erreurs ci-dessous."
      render :new, status: :unprocessable_entity
    end
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization, :location,
      :image, :gallery_image_1, :gallery_image_2, :gallery_image_3,
      :contact_email, :website, photos: []
    )
  end
end
