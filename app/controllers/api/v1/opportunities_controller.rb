# app/controllers/api/v1/opportunities_controller.rb
class Api::V1::OpportunitiesController < ApplicationController
  protect_from_forgery with: :null_session

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  # GET /api/v1/opportunities
  # Params acceptés :
  #   q=texte
  #   category=benevolat|formation|rencontres|entreprendre
  #   lat=..&lng=..&radius=25   (km)
  #   page=1&per=24
  #   order=recent|near        (near priorise lat/lng si fournis)
  def index
    lat    = params[:lat]
    lng    = params[:lng]
    radius = (params[:radius].presence || 25).to_f
    q      = params[:q].to_s.strip.presence
    cat    = params[:category].to_s.strip.presence

    page = params[:page].to_i
    page = 1 if page < 1
    per  = params[:per].to_i
    per  = 24 if per <= 0
    per  = 100 if per > 100 # garde une limite raisonnable

    scope = Opportunity.active
                       .with_category(cat)
                       .search_text(q)
                       .near_ll(lat, lng, radius)

    # Tri : par défaut les plus “récents”
    if params[:order] == 'near' && lat.present? && lng.present?
      # Geocoder::Model::ActiveRecord::near renvoie déjà par distance
      # donc on ne touche pas à l'ordre.
    else
      scope = scope.order(updated_at: :desc)
    end

    total  = scope.count
    offset = (page - 1) * per
    records = scope.limit(per).offset(offset)

    # Bounds (pour fitBounds côté Leaflet)
    lats = records.map(&:latitude).compact
    lngs = records.map(&:longitude).compact
    bounds = if lats.any? && lngs.any?
      { min_lat: lats.min.to_f, max_lat: lats.max.to_f, min_lng: lngs.min.to_f, max_lng: lngs.max.to_f }
    else
      nil
    end

    render json: {
      data: records.map { |o| serialize_opportunity(o) },
      meta: {
        page: page,
        per: per,
        total: total,
        total_pages: (total.to_f / per).ceil,
        q: q, category: cat,
        lat: lat&.to_f, lng: lng&.to_f, radius_km: radius,
        bounds: bounds
      }
    }
  end

  # GET /api/v1/opportunities/:id
  # Compatible FriendlyId si activé
  def show
    record =
      if Opportunity.respond_to?(:friendly)
        Opportunity.friendly.find(params[:id])
      else
        Opportunity.find(params[:id])
      end

    render json: { data: serialize_opportunity(record) }
  end

  private

  def serialize_opportunity(o)
    {
      id:           o.id,
      title:        o.title,
      description:  o.description,
      category:     o.category,
      organization: o.organization,
      location:     o.location,
      time_commitment: o.time_commitment,
      effort_level:    o.effort_level,
      tags:            o.respond_to?(:tag_list) ? o.tag_list : o.tags,
      latitude:     o.latitude&.to_f,
      longitude:    o.longitude&.to_f,
      updated_at:   o.updated_at
    }
  end
end


