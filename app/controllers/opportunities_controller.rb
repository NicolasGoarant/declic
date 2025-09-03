# app/controllers/opportunities_controller.rb
class OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: :show

# app/controllers/opportunities_controller.rb
def new
  @opportunity = Opportunity.new
end

  def create
    @opportunity = Opportunity.new(opportunity_params)
    if @opportunity.save
      redirect_to @opportunity, notice: "Merci ! Votre proposition a été envoyée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  private

  def set_opportunity
    @opportunity =
      (Opportunity.respond_to?(:friendly) ? Opportunity.friendly : Opportunity)
        .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @opportunity = Opportunity.find(params[:id]) # fallback si pas de slug
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization, :location,
      :time_commitment, :latitude, :longitude, :website,
      :contact_email, :contact_phone, :is_active
    )
  end
end


