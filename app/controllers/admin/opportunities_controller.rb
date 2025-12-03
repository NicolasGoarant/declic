class Admin::OpportunitiesController < Admin::BaseController
  before_action :set_opportunity, only: [:edit, :update, :destroy, :toggle_active]

  # GET /admin/opportunities
  def index
    @q       = params[:q].to_s.strip
    @only_in = ActiveModel::Type::Boolean.new.cast(params[:only_inactive])
    @missing = ActiveModel::Type::Boolean.new.cast(params[:missing_coords])
    @cat     = params[:category].presence

    scope = Opportunity.all
    scope = scope.where("LOWER(title) LIKE ?", "%#{@q.downcase}%") if @q.present?
    scope = scope.where(category: @cat) if @cat.present?
    scope = scope.where(is_active: false) if @only_in
    scope = scope.where(latitude: nil).or(scope.where(longitude: nil)) if @missing

    @opportunities = scope
      .order(Arel.sql("COALESCE(starts_at, created_at) DESC"))
      .limit(500)

    @counts = {
      total:          Opportunity.count,
      active:         Opportunity.where(is_active: true).count,
      missing_coords: Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).count
    }
  end

  # GET /admin/opportunities/new
  def new
    @opportunity = Opportunity.new(is_active: true)
  end

  # POST /admin/opportunities
  def create
    @opportunity = Opportunity.new(opportunity_params)

    if @opportunity.save
      redirect_to admin_opportunities_path, notice: "Opportunité créée."
    else
      flash.now[:alert] = @opportunity.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/opportunities/:id/edit
  def edit; end

  # PATCH/PUT /admin/opportunities/:id
  def update
    if @opportunity.update(opportunity_params)
      redirect_to admin_opportunities_path(q: params[:q]), notice: "Opportunité mise à jour."
    else
      flash.now[:alert] = @opportunity.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/opportunities/:id
  def destroy
    @opportunity.destroy
    redirect_to admin_opportunities_path, notice: "Opportunité supprimée."
  end

  # PATCH /admin/opportunities/:id/toggle_active (AJAX)
  def toggle_active
    new_state = ActiveModel::Type::Boolean.new.cast(params[:is_active])

    if @opportunity.update(is_active: new_state)
      render json: {
        success:   true,
        message:   "Opportunité #{new_state ? 'activée' : 'désactivée'}",
        is_active: @opportunity.is_active
      }
    else
      render json: {
        success: false,
        message: "Erreur lors de la mise à jour",
        errors:  @opportunity.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /admin/opportunities/bulk
  def bulk
    ids    = Array(params[:ids]).map(&:to_i).uniq
    action = params[:bulk_action].to_s

    return redirect_to admin_opportunities_path,
                       alert: "Sélection vide ou action manquante." if ids.empty? || action.blank?

    scope = Opportunity.where(id: ids)

    msg =
      case action
      when "activate"
        scope.update_all(is_active: true)
        "Activées : #{scope.count}"
      when "deactivate"
        scope.update_all(is_active: false)
        "Désactivées : #{scope.count}"
      when "destroy"
        count = scope.count
        scope.find_each(&:destroy!)
        "Supprimées : #{count}"
      else
        "Action inconnue."
      end

    redirect_to admin_opportunities_path(request.query_parameters), notice: msg
  end

  # POST /admin/opportunities/geocode_missing
  def geocode_missing
    scope = Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil))
    done  = 0

    scope.find_each do |o|
      has_address_bits =
        o.location.present? ||
        (o.respond_to?(:address)  && o.address.present?) ||
        (o.respond_to?(:city)     && o.city.present?)    ||
        (o.respond_to?(:postcode) && o.postcode.present?)

      done += 1 if has_address_bits && o.save
    end

    redirect_to admin_opportunities_path(request.query_parameters),
                notice: "Géocodage tenté sur #{done} élément(s)."
  end

  private

  def set_opportunity
    @opportunity = Opportunity.find(params[:id])
  end

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
      :image_url,     # URL éventuelle
      :image,         # upload Active Storage
      :source_url,
      :website,
      :contact_email,
      :contact_phone,
      :tags
    )
  end
end
