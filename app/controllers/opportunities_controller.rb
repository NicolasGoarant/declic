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
      format.html # index.html.erb
      format.json { render json: @opportunities.as_json(only: %i[id slug title description category organization location time_commitment latitude longitude image_url]) }
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
  def create
    @opportunity = Opportunity.new(opportunity_params)
    if @opportunity.save
      redirect_to @opportunity, notice: "Opportunité créée."
    else
      flash.now[:alert] = @opportunity.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization, :location,
      :time_commitment, :starts_at, :ends_at, :latitude, :longitude,
      :is_active, :image_url, :source_url, :tags
    )
  end
end
