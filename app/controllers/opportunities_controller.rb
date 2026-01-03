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

  # MODIFICATION : Forcer is_active à false pour modération
  def create
    @opportunity = Opportunity.new(opportunity_params)
    @opportunity.is_active = false

    if @opportunity.save
      OpportunityProposalMailer.with(opportunity: @opportunity).proposal_email.deliver_later
      redirect_to merci_opportunities_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def merci; end

  private

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization,
      :location, :contact_email, :website
    )
  end
end
