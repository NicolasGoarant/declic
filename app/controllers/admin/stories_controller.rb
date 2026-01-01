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

    apply_import_blob(@story)

    if @story.errors.none? && @story.save
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
    @story.assign_attributes(story_params)

    apply_import_blob(@story)

    if @story.errors.none? && @story.save
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
  def geocode_missing
    scope = Story.where(latitude: nil).or(Story.where(longitude: nil))
    done  = 0

    scope.find_each do |s|
      if s.location.present?
        s.geocode

        if s.latitude.present? && s.longitude.present?
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
      :inline_image_1,
      :inline_caption_1,
      :inline_image_2,
      :inline_caption_2,
      :inline_image_3,
      :inline_caption_3,
      :source_name, :source_url,
      :slug, :tags, :active, :is_active, :published,
      :highlights_title,
      :highlights_text,
      :highlights_items,
      :contact_info
    )
  end

  # Si params[:import_blob] est présent :
  # - parse frontmatter + body
  # - remplit les champs (prioritaire sur le formulaire)
  # - tente un géocodage si location présente mais coords absentes
  def apply_import_blob(story)
    blob = params[:import_blob].to_s
    return if blob.blank?

    begin
      attrs, body = ImportStoryParser.call(blob)

      # Import prioritaire sur les champs du formulaire
      story.assign_attributes(attrs)
      story.body = body if body.present?

      # Géocodage automatique si on a une adresse mais pas de coords
      if story.location.present? &&
         (story.latitude.blank? || story.longitude.blank?) &&
         story.respond_to?(:geocode)
        story.geocode
      end
    rescue ImportStoryParser::ParseError => e
      story.errors.add(:base, "Import Story : #{e.message}")
    rescue => e
      story.errors.add(:base, "Import Story : erreur inattendue (#{e.class})")
    end
  end
end
