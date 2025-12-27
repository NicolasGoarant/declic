class Admin::StoriesController < Admin::BaseController
  before_action :set_story, only: [:edit, :update, :destroy]

  # GET /admin/stories
  def index
    @q       = params[:q].to_s.strip
    @missing = ActiveModel::Type::Boolean.new.cast(params[:missing_coords])

    scope = Story.all
    if @q.present?
      q_like = "%#{@q.downcase}%"
      scope = scope.where(
        "LOWER(title) LIKE :q OR LOWER(chapo) LIKE :q OR LOWER(description) LIKE :q OR LOWER(body) LIKE :q",
        q: q_like
      )
    end
    scope = scope.where(latitude: nil).or(scope.where(longitude: nil)) if @missing

    @stories = scope
      .order(Arel.sql("COALESCE(updated_at, created_at) DESC"))
      .limit(500)

    @counts = {
      total:          Story.count,
      missing_coords: Story.where(latitude: nil).or(Story.where(longitude: nil)).count
    }
  end

  # GET /admin/stories/new
  def new
    @story = Story.new
  end

  # POST /admin/stories
  def create
    @story = Story.new(story_params)
    if @story.save
      redirect_to admin_stories_path, notice: "Histoire créée."
    else
      flash.now[:alert] = @story.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
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

    msg =
      case action
      when "destroy"
        count = scope.count
        scope.find_each(&:destroy!)
        "Supprimées : #{count}"
      when "activate"
        if Story.column_names.include?("is_active")
          scope.update_all(is_active: true)
          "Activées : #{scope.count}"
        else
          "Action 'activate' indisponible (colonne is_active absente)."
        end
      when "deactivate"
        if Story.column_names.include?("is_active")
          scope.update_all(is_active: false)
          "Désactivées : #{scope.count}"
        else
          "Action 'deactivate' indisponible (colonne is_active absente)."
        end
      else
        "Action inconnue."
      end

    redirect_to admin_stories_path(request.query_parameters), notice: msg
  end

  # POST /admin/stories/geocode_missing
# POST /admin/stories/geocode_missing
  def geocode_missing
    # On sélectionne toutes les stories qui manquent de latitude OU de longitude
    scope = Story.where(latitude: nil).or(Story.where(longitude: nil))
    done  = 0

    scope.find_each do |s|
      # On s'assure qu'une adresse est présente pour géocoder
      if s.location.present?

        # 1. FORCER LE GÉOCODAGE
        # On appelle la méthode `geocode` fournie par la gemme Geocoder
        s.geocode

        # 2. VÉRIFIER SI LES COORDONNÉES ONT ÉTÉ TROUVÉES
        if s.latitude.present? && s.longitude.present?
          # 3. SAUVEGARDER UNIQUEMENT LES COORDONNÉES
          # update_columns est plus rapide et évite de relancer des validations inutiles.
          s.update_columns(latitude: s.latitude, longitude: s.longitude, updated_at: Time.current)
          done += 1
        end
      end
    end

    redirect_to admin_stories_path(request.query_parameters),
                notice: "Géocodage forcé sur les fiches manquantes : #{done} élément(s) mis à jour avec succès."
  end

  private

  def set_story
    @story = Story.find_by(id: params[:id]) || Story.find_by!(slug: params[:id])
  end

def story_params
  params.require(:story).permit(
    :title, :chapo, :body, :description,
    :happened_on, :location, :latitude, :longitude,
    :image, :image_url,
    :source_name, :source_url,
    :slug, :tags, :active, :is_active, :published,
    :highlights_title,     # ← NOUVEAU
    :highlights_text,      # ← NOUVEAU
    :highlights_items      # ← NOUVEAU
  )
end
end
