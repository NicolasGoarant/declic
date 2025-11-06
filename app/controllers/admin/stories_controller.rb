# app/controllers/admin/stories_controller.rb
class Admin::StoriesController < Admin::BaseController
  before_action :set_story, only: [:edit, :update, :destroy]

  # GET /admin/stories
  def index
    @q        = params[:q].to_s.strip
    @missing  = ActiveModel::Type::Boolean.new.cast(params[:missing_coords])

    scope = Story.all
    if @q.present?
      q_like = "%#{@q.downcase}%"
      scope = scope.where(
        "LOWER(title) LIKE :q OR LOWER(chapo) LIKE :q OR LOWER(description) LIKE :q OR LOWER(body) LIKE :q",
        q: q_like
      )
    end
    if @missing
      scope = scope.where(latitude: nil).or(scope.where(longitude: nil))
    end

    @stories = scope.order(Arel.sql("COALESCE(updated_at, created_at) DESC")).limit(500)

    @counts = {
      total: Story.count,
      missing_coords: Story.where(latitude: nil).or(Story.where(longitude: nil)).count
    }
  end

  # GET /admin/stories/:id/edit
  def edit; end

  # PATCH/PUT /admin/stories/:id
  def update
    if @story.update(story_params)
      redirect_to admin_stories_path(request.query_parameters), notice: "Histoire mise à jour."
    else
      flash.now[:alert] = @story.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/stories/:id
  def destroy
    @story.destroy
    redirect_to admin_stories_path(request.query_parameters), notice: "Histoire supprimée."
  end

  # POST /admin/stories/bulk
  def bulk
    ids    = Array(params[:ids]).map(&:to_i).uniq
    action = params[:bulk_action].to_s

    if ids.empty? || action.blank?
      return redirect_to admin_stories_path, alert: "Sélection vide ou action manquante."
    end

    scope = Story.where(id: ids)
    case action
    when "destroy"
      count = scope.count
      scope.find_each(&:destroy!)
      msg = "Supprimées : #{count}"
    when "activate"
      # Seulement si tu ajoutes is_active:boolean sur Story
      if Story.column_names.include?("is_active")
        scope.update_all(is_active: true)
        msg = "Activées : #{scope.count}"
      else
        msg = "Action 'activate' indisponible (colonne is_active absente)."
      end
    when "deactivate"
      if Story.column_names.include?("is_active")
        scope.update_all(is_active: false)
        msg = "Désactivées : #{scope.count}"
      else
        msg = "Action 'deactivate' indisponible (colonne is_active absente)."
      end
    else
      msg = "Action inconnue."
    end

    redirect_to admin_stories_path(request.query_parameters), notice: msg
  end

  # POST /admin/stories/geocode_missing
  def geocode_missing
    scope = Story.where(latitude: nil).or(Story.where(longitude: nil))
    done = 0
    scope.find_each do |s|
      if s.location.present? || [s.try(:address), s.try(:city), s.try(:postcode)].any?(&:present?)
        done += 1 if s.save # déclenche éventuellement before_validation si tu en ajoutes un
      end
    end
    redirect_to admin_stories_path(request.query_parameters), notice: "Géocodage tenté sur #{done} élément(s)."
  end

private

  def set_story
  # Essaie d'abord l'ID numérique, puis le slug
      @story = Story.find_by(id: params[:id]) || Story.find_by!(slug: params[:id])
  end

  def story_params
    params.require(:story).permit(
      :title, :chapo, :description, :body,
      :location, :latitude, :longitude,
      :source_name, :source_url, :image_url,
      :tags, :slug # si friendly_id
      # :is_active # <- seulement si tu l'ajoutes au modèle
    )
  end
end
