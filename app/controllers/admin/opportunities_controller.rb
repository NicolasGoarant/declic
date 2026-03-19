# frozen_string_literal: true

class Admin::OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: [:edit, :update, :destroy, :toggle_active]

  def index
    scope = Opportunity.all

    @q = params[:q].to_s.strip
    @cat = params[:category].to_s.strip
    @only_in = params[:only_inactive].present?
    @missing = params[:missing_coords].present?

    scope = scope.where("title ILIKE ?", "%#{@q}%") if @q.present?
    scope = scope.where(category: @cat) if @cat.present?
    scope = scope.where(is_active: false) if @only_in
    scope = scope.where(latitude: nil).or(scope.where(longitude: nil)) if @missing

    @opportunities = scope.order(created_at: :desc)

    @counts = {
      total: Opportunity.count,
      active: Opportunity.where(is_active: true).count,
      missing_coords: Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).count
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
    Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).find_each do |o|
      o.geocode
      if o.latitude.present? && o.longitude.present?
        o.save(validate: false)
        count += 1
      end
    end
    redirect_to admin_opportunities_path, notice: "Géocodage terminé (#{count} mises à jour)."
  end

  private

  def set_opportunity
    @opportunity = Opportunity.find(params[:id])
  end

  def opportunity_params
    params.require(:opportunity).permit(
      # Contenu principal
      :title,
      :category,
      :organization,
      :description,
      :is_active,

      # Citation / Témoignage
      :quote,
      :quote_author,

      # Statistiques d'impact
      :stat_1_number,
      :stat_1_label,
      :stat_2_number,
      :stat_2_label,
      :stat_3_number,
      :stat_3_label,
      :stat_4_number,
      :stat_4_label,

      # Défis surmontés
      :challenges,

      # Localisation
      :location,
      :latitude,
      :longitude,
      :address,
      :city,
      :postal_code,

      # Dates & horaires
      :start_date,
      :end_date,
      :time_commitment,

      # Images
      :image,
      :image_url,

      # Images inline (système <!-- IMAGE_1/2/3 -->)
      :inline_image_1,
      :inline_image_2,
      :inline_image_3,
      :inline_caption_1,
      :inline_caption_2,
      :inline_caption_3,

      # Anciennes images galerie (pour compatibilité si encore utilisées)
      :gallery_image_1,
      :gallery_image_2,
      :gallery_image_3,

      # Source & Contact
      :source_name,
      :source_url,
      :website,
      :contact_email,
      :contact_phone,
      :phone,

      # SEO & Organisation
      :slug,
      :tags,

      # Photos multiples (si utilisé)
      photos: []
    )
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

  def filtered_opportunity_params
  # Ne garde que les paramètres dont la colonne existe
  permitted = opportunity_params
  existing_columns = Opportunity.column_names.map(&:to_sym)

  permitted.select do |key, value|
    # Les uploads sont toujours autorisés
    value.is_a?(ActionDispatch::Http::UploadedFile) ||
    key == :photos ||
    existing_columns.include?(key.to_sym)
  end
end


end
