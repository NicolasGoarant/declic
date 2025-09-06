# app/controllers/opportunities_controller.rb
class OpportunitiesController < ApplicationController
  layout "application"   # <— force l’usage du layout avec la navbar
  def new
    @opportunity = Opportunity.new
  end

  def create
    @opportunity = Opportunity.new(opportunity_params)
    @opportunity.is_active = true if @opportunity.is_active.nil?

    if @opportunity.save
      redirect_to @opportunity, notice: "Merci ! Votre opportunité a été proposée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @category = params[:category].presence
    scope = Opportunity.active.order(created_at: :desc)
    scope = scope.where(category: @category) if @category.in?(Opportunity::CATEGORIES)
    @opportunities = scope.limit(60)
  end

  def show
    @opportunity = Opportunity.find(params[:id])
  end

  
  private

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization, :location,
      :latitude, :longitude, :time_commitment, :effort_level,
      :starts_at, :ends_at, :tags, :contact_email, :contact_phone, :website, :is_active,

      # --- Nouveaux champs "virage" ---
      :audience_level, :career_outcome, :skills, :credential,
      :mentorship, :alumni_network, :hiring_partners,
      :format, :schedule, :duration_weeks, :application_deadline,
      :selectivity_level, :prerequisites,
      :cost_eur, :is_free, :scholarship_available, :funding_options,
      :accessibility, :impact_domains, :impact_metric_hint
    )
  end
end

