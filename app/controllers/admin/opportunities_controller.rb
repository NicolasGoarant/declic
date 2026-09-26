# frozen_string_literal: true

class Admin::OpportunitiesController < Admin::BaseController
  before_action :set_opportunity, only: [ :edit, :update, :destroy, :toggle_active ]
  include TriParCompletude

  def index
    scope = Opportunity.all

    @q = params[:q].to_s.strip
    @cat = params[:category].to_s.strip
    @only_in = params[:only_inactive].present?
    @missing = params[:missing_coords].present?
    @flagged = params[:geocoding_flagged].present?

    # matches : ILIKE en Postgres, LIKE en SQLite ; les jokers saisis sont échappés.
    scope = scope.where(Opportunity.arel_table[:title].matches("%#{Opportunity.sanitize_sql_like(@q)}%", "\\")) if @q.present?
    scope = scope.where(category: @cat) if @cat.present?
    scope = scope.where(is_active: false) if @only_in
    scope = scope.where(latitude: nil).or(scope.where(longitude: nil)) if @missing
    scope = scope.where.not(geocoding_flagged_reason: nil) if @flagged

    @tri, @sens = tri_fiche_params
    @opportunities = trier_par_completude(scope.includes(:image_attachment, :photos_attachments).order(created_at: :desc), @tri, @sens)

    @counts = {
      total: Opportunity.count,
      active: Opportunity.where(is_active: true).count,
      missing_coords: Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).count,
      # Signalées par le garde-fou de distance (NancyGeocodable) : un résultat
      # de géocodage à plus de 30 km de Nancy, refusé au lieu d'enregistré.
      geocoding_flagged: Opportunity.where.not(geocoding_flagged_reason: nil).count
    }
  end

  def new
    @opportunity = Opportunity.new
  end

  def edit; end

  def create
    @opportunity = Opportunity.new(opportunity_params)

    # N'applique l'import_blob QUE s'il est présent
    apply_import_blob!(@opportunity) if params[:import_blob].present?

    if @opportunity.save
      appliquer_galerie(@opportunity)
      redirect_to admin_opportunities_path, notice: "Opportunité créée ✅"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @opportunity.assign_attributes(opportunity_params)

    # N'applique l'import_blob QUE s'il est présent
    apply_import_blob!(@opportunity) if params[:import_blob].present?

    if @opportunity.save
      appliquer_galerie(@opportunity)
      redirect_to admin_opportunities_path, notice: "Opportunité mise à jour ✅"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @opportunity.destroy
    redirect_to admin_opportunities_path, notice: "Opportunité supprimée 🗑️"
  end

  def toggle_active
    @opportunity.update_column(:is_active, !@opportunity.is_active)
    redirect_back fallback_location: admin_opportunities_path, notice: "Statut mis à jour."
  end

  def geocode_missing
    count = 0
    signalees = 0
    Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).find_each do |o|
      o.geocode_and_guard
      if o.latitude.present? && o.longitude.present?
        o.save(validate: false)
        count += 1
      elsif o.geocoding_flagged_reason.present?
        # Rejeté par le garde-fou de distance (NancyGeocodable) : on écrit le
        # motif quand même, pour que l'admin le voie, mais pas de coordonnées.
        o.save(validate: false)
        signalees += 1
      end
    end
    redirect_to admin_opportunities_path,
                notice: "Géocodage terminé (#{count} mises à jour, #{signalees} signalée(s) hors zone)."
  end

  private

  def set_opportunity
    @opportunity = Opportunity.find(params[:id])
  end

  def opportunity_params
    params.require(:opportunity).permit(
      # Identité
      :title, :category, :organization, :organization_logo, :is_active,

      # Dates & horaires (les chaînes start_date / end_date sont écrites par le pont du modèle)
      :starts_on, :ends_on, :start_time, :end_time, :schedule_text, :time_commitment,

      # Lieu
      :location, :latitude, :longitude, :address, :city, :postal_code,

      # Contenu
      :description, :audience, :programme_texte, :quote, :quote_author,
      :stat_1_number, :stat_1_label, :stat_2_number, :stat_2_label,
      :stat_3_number, :stat_3_label, :stat_4_number, :stat_4_label,
      :challenges,

      # Images (la galerie `photos` passe par appliquer_galerie)
      :image, :image_url,
      :inline_image_1, :inline_image_2, :inline_image_3,
      :inline_caption_1, :inline_caption_2, :inline_caption_3,

      # Action
      :cta_button_text, :cta_button_url,

      # Source & contact
      :source_name, :source_url, :website, :contact_email, :contact_phone, :phone,

      # Publication
      :published_at, :slug, :tags
    )
  end

  # Galerie : nouveaux fichiers, suppressions et positions saisies (voir GaleriePhotos).
  def appliquer_galerie(opportunity)
    galerie = params.fetch(:galerie, {}).permit(nouvelles: [], supprimer: [], positions: {})
    opportunity.organization_logo.purge if params[:supprimer_logo] == "1"
    opportunity.appliquer_galerie(nouvelles: galerie[:nouvelles], supprimer: galerie[:supprimer],
                                  positions: galerie[:positions])
  end

  def apply_import_blob!(opportunity)
    blob = params[:import_blob].to_s
    return if blob.strip.blank?

    # Logique d'import simplifiée pour éviter les erreurs de mapping complexes
    require "yaml"

    begin
      parts = blob.split(/^---\s*$\n?/, 3)

      if parts.size >= 3
        data = YAML.safe_load(parts[1]) || {}
        opportunity.assign_attributes(data.slice(*Opportunity.column_names))
        opportunity.description = parts[2].strip if parts[2].present?
      end
    rescue => e
      Rails.logger.error("[apply_import_blob!] Erreur: #{e.message}")
      opportunity.errors.add(:base, "Erreur lors de l'import du bloc")
    end
  end
end
