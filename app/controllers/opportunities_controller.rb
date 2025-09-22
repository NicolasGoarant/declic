# frozen_string_literal: true

class OpportunitiesController < ApplicationController
  layout "application"

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
    scope = Opportunity.active.order(starts_at: :asc, created_at: :desc)
    scope = scope.where(category: @category) if @category.in?(Opportunity::CATEGORIES)
    @opportunities = scope.limit(200)

    respond_to do |format|
      format.html
      format.json do
        render json: @opportunities.as_json(
          only: [
            :id, :title, :latitude, :longitude, :starts_at, :venue_name, :city, :url, :category, :source
          ]
        )
      end
    end
  end

  def show
    @opportunity = Opportunity.find(params[:id])
  end

  private

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization, :location,
      :latitude, :longitude, :time_commitment, :effort_level,
      :starts_at, :ends_at, :tags, :contact_email, :contact_phone,
      :website, :is_active, :address, :city, :postcode, :venue_name,

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
