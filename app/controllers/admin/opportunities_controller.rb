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
    apply_import_blob!(@opportunity)

    if @opportunity.save
      redirect_to admin_opportunities_path, notice: "Opportunité créée ✅"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @opportunity.assign_attributes(opportunity_params)
    apply_import_blob!(@opportunity)

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
      :title, :category, :organization, :description, :is_active,
      :location, :latitude, :longitude, :tags,
      :address, :city, :postal_code, :website, :contact_email, :phone,
      :image, :image_url,
      :gallery_image_1, :gallery_image_2, :gallery_image_3,
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
    rescue
      opportunity.errors.add(:base, "Erreur lors de l'import du bloc")
    end
  end
end
