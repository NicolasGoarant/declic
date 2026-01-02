# frozen_string_literal: true

class Admin::OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: [:edit, :update, :destroy, :toggle_active]

  # GET /admin/opportunities
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

    # ✅ Stats attendues par app/views/admin/opportunities/index.html.erb
    @counts = {
      total: Opportunity.count,
      active: Opportunity.where(is_active: true).count,
      missing_coords: Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).count
    }
  end

  # GET /admin/opportunities/new
  def new
    @opportunity = Opportunity.new
  end

  # GET /admin/opportunities/:id/edit
  def edit
  end

  # POST /admin/opportunities
  def create
    @opportunity = Opportunity.new(opportunity_params)

    begin
      apply_import_blob!(@opportunity)
    rescue StandardError => e
      @opportunity.errors.add(:base, "Import Opportunité : erreur inattendue (#{e.class})")
      flash.now[:alert] = "Import Opportunité : erreur inattendue (#{e.class})"
      return render :new, status: :unprocessable_entity
    end

    if @opportunity.save
      redirect_to edit_admin_opportunity_path(@opportunity), notice: "Opportunité créée ✅"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/opportunities/:id
  def update
    @opportunity.assign_attributes(opportunity_params)

    begin
      apply_import_blob!(@opportunity)
    rescue StandardError => e
      @opportunity.errors.add(:base, "Import Opportunité : erreur inattendue (#{e.class})")
      flash.now[:alert] = "Import Opportunité : erreur inattendue (#{e.class})"
      return render :edit, status: :unprocessable_entity
    end

    if @opportunity.save
      redirect_to edit_admin_opportunity_path(@opportunity), notice: "Opportunité mise à jour ✅"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/opportunities/:id
  def destroy
    @opportunity.destroy
    redirect_to admin_opportunities_path, notice: "Opportunité supprimée 🗑️"
  end

  # POST /admin/opportunities/bulk
  def bulk
    ids = Array(params[:ids]).map(&:to_i).uniq
    action = params[:bulk_action].to_s

    if ids.empty?
      return redirect_to admin_opportunities_path, alert: "Aucune opportunité sélectionnée."
    end

    scope = Opportunity.where(id: ids)

    case action
    when "activate"
      scope.update_all(is_active: true)
      redirect_to admin_opportunities_path, notice: "Opportunités activées ✅"
    when "deactivate"
      scope.update_all(is_active: false)
      redirect_to admin_opportunities_path, notice: "Opportunités désactivées ✅"
    when "destroy"
      scope.destroy_all
      redirect_to admin_opportunities_path, notice: "Opportunités supprimées 🗑️"
    else
      redirect_to admin_opportunities_path, alert: "Action groupée invalide."
    end
  end

  # POST /admin/opportunities/geocode_missing
  def geocode_missing
    count = 0

    Opportunity.where(latitude: nil).or(Opportunity.where(longitude: nil)).find_each do |o|
      next unless o.respond_to?(:geocode)

      o.geocode
      if o.latitude.present? && o.longitude.present?
        o.save(validate: false)
        count += 1
      end
    end

    redirect_to admin_opportunities_path, notice: "Géocodage terminé (#{count} mises à jour)."
  end

  # PATCH /admin/opportunities/:id/toggle_active (AJAX)
  def toggle_active
    new_state =
      ActiveModel::Type::Boolean.new.cast(params[:is_active])

    # On bypass les validations (sinon une fiche incomplète peut empêcher le toggle)
    @opportunity.update_column(:is_active, new_state)

    render json: {
      success: true,
      message: "Opportunité #{new_state ? 'activée' : 'désactivée'}",
      is_active: @opportunity.is_active
    }
  rescue => e
    render json: {
      success: false,
      message: "Erreur lors de la mise à jour",
      errors: [e.message]
    }, status: :unprocessable_entity
  end


  private

  def set_opportunity
    @opportunity = Opportunity.find(params[:id])
  end

  def opportunity_params
    params.require(:opportunity).permit(
      :title, :category, :organization, :description,
      :is_active,
      :quote, :quote_author,
      :stat_1_number, :stat_1_label,
      :stat_2_number, :stat_2_label,
      :stat_3_number, :stat_3_label,
      :stat_4_number, :stat_4_label,
      :challenges,
      :location, :latitude, :longitude,
      :starts_at, :ends_at, :time_commitment,
      # ⚠️ source_name supprimé (champ inexistant => crash)
      :source_url,
      :contact_email, :contact_phone, :website_url,
      :image, :image_url,
      :gallery_image_1, :gallery_image_1_url,
      :gallery_image_2, :gallery_image_2_url,
      :gallery_image_3, :gallery_image_3_url,
      :slug, :tags
    )
  end

  # Applique le bloc "⚡ Import Opportunité (bêta)"
  # Format attendu :
  # ---
  # title: "🧤 ..."
  # category: benevolat
  # organization: "..."
  # location: "..."
  # lat: 48.69
  # lng: 6.18
  # ...
  # ---
  # description en dessous (markdown possible)
  def apply_import_blob!(opportunity)
    blob = params[:import_blob].to_s
    return if blob.strip.blank?

    blob = blob.strip

    fm = nil
    body = nil

    if blob.start_with?("---")
      parts = blob.split(/^---\s*$\n?/, 3)
      fm = parts[1].to_s
      body = parts[2].to_s
    else
      body = blob
    end

    data = {}
    if fm.present?
      require "yaml"
      parsed = YAML.safe_load(fm, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
      data = parsed.is_a?(Hash) ? parsed : {}
    end

    # -----------------------------
    # 1) Construire un hash attrs
    # -----------------------------
    attrs = {}

    def pick(data, *keys)
      keys.each do |k|
        return data[k] if data.key?(k)
        return data[k.to_sym] if k.is_a?(String) && data.key?(k.to_sym)
        return data[k.to_s] if k.is_a?(Symbol) && data.key?(k.to_s)
      end
      nil
    end

    attrs["title"]        = pick(data, "title", :title)
    attrs["category"]     = pick(data, "category", :category)
    attrs["organization"] = pick(data, "organization", :organization)
    attrs["location"]     = pick(data, "location", :location)

    lat = pick(data, "lat", :lat, "latitude", :latitude)
    lng = pick(data, "lng", :lng, "lon", :lon, "longitude", :longitude)

    attrs["latitude"]  = lat if lat.present?
    attrs["longitude"] = lng if lng.present?

    attrs["time_commitment"] = pick(data, "time_commitment", :time_commitment)
    attrs["quote"]           = pick(data, "quote", :quote)
    attrs["quote_author"]    = pick(data, "quote_author", :quote_author)

    attrs["stat_1_number"] = pick(data, "stat_1_number", :stat_1_number)
    attrs["stat_1_label"]  = pick(data, "stat_1_label", :stat_1_label)
    attrs["stat_2_number"] = pick(data, "stat_2_number", :stat_2_number)
    attrs["stat_2_label"]  = pick(data, "stat_2_label", :stat_2_label)
    attrs["stat_3_number"] = pick(data, "stat_3_number", :stat_3_number)
    attrs["stat_3_label"]  = pick(data, "stat_3_label", :stat_3_label)
    attrs["stat_4_number"] = pick(data, "stat_4_number", :stat_4_number)
    attrs["stat_4_label"]  = pick(data, "stat_4_label", :stat_4_label)

    attrs["challenges"] = pick(data, "challenges", :challenges)

    attrs["source_url"]    = pick(data, "source_url", :source_url)
    attrs["website_url"]   = pick(data, "website", :website, "website_url", :website_url)
    attrs["contact_email"] = pick(data, "contact_email", :contact_email)
    attrs["contact_phone"] = pick(data, "contact_phone", :contact_phone)

    tags_val = pick(data, "tags", :tags)
    if tags_val.is_a?(Array)
      attrs["tags"] = tags_val.join(", ")
    else
      attrs["tags"] = tags_val
    end

    # Description = body (si présent)
    if body.present?
      attrs["description"] = body.to_s.strip
    end

    # -----------------------------
    # 2) Sécuriser : ignorer toute clé inconnue (évite crash)
    # -----------------------------
    allowed = Opportunity.column_names
    safe_attrs = attrs.select { |k, v| allowed.include?(k.to_s) && v.present? }

    # -----------------------------
    # 3) Assigner (avec conversions min)
    # -----------------------------
    safe_attrs.each do |k, v|
      case k.to_s
      when "latitude", "longitude"
        opportunity.public_send("#{k}=", v.to_f)
      else
        opportunity.public_send("#{k}=", v.to_s) if v.is_a?(Numeric)
        opportunity.public_send("#{k}=", v)
      end
    end
  end
end
