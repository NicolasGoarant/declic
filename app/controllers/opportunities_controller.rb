class OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: :show

  # GET /opportunities
  # HTML : page liste
  # JSON : petite API de secours (utile si nécessaire)
  def index
    @category = params[:category].presence
    @q        = params[:q].to_s.strip

    scope = Opportunity.where(is_active: true)
    scope = scope.where(category: @category) if @category
    scope = scope.where("title LIKE :q OR description LIKE :q OR organization LIKE :q", q: "%#{@q}%") if @q.present?

    @opportunities = scope.order(created_at: :desc).limit(100)

    respond_to do |format|
      format.html # rendra index.html.erb
      format.json do
        render json: @opportunities.select(
          :id, :title, :description, :category, :organization,
          :location, :time_commitment, :latitude, :longitude
        ).map { |o| o.as_json.merge(latitude: o.latitude&.to_f, longitude: o.longitude&.to_f) }
      end
    end
  end

  # GET /opportunities/:id
  def show
  end

  # GET /opportunities/new
  def new
    @opportunity = Opportunity.new(category: "benevolat")
  end

  # POST /opportunities
  def create
    @opportunity = Opportunity.new(opportunity_params)
    # En attendant une modération, on peut le mettre actif ou non selon ton choix :
    @opportunity.is_active = true if @opportunity.is_active.nil?

    if @opportunity.save
      redirect_to @opportunity, notice: "Merci ! Votre opportunité a bien été enregistrée."
    else
      flash.now[:alert] = "Merci de corriger les champs indiqués."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_opportunity
    # FriendlyId si configuré, sinon fallback
    @opportunity =
      if Opportunity.respond_to?(:friendly)
        Opportunity.friendly.find(params[:id])
      else
        Opportunity.find(params[:id])
      end
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :description, :category, :organization,
      :location, :address, :city, :postcode, :website,
      :contact_email, :contact_phone, :tags, :effort_level, :time_commitment,
      :latitude, :longitude, :is_active
    )
  end
end



