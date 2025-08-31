# app/controllers/api/v1/opportunities_controller.rb
class Api::V1::OpportunitiesController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    scope = Opportunity.where(is_active: true)

    # Filtre catégorie (ex: ?category=benevolat ou ?category=benevolat,formation)
    if params[:category].present?
      cats = Array(params[:category])
               .flat_map { |c| c.to_s.split(',') }
               .map(&:strip).reject(&:blank?)
      scope = scope.where(category: cats) if cats.any?
    end

    # Filtre géo : bbox=minLat,minLng,maxLat,maxLng
    if params[:bbox].present?
      a = params[:bbox].split(',').map(&:to_f)
      if a.size == 4
        min_lat, min_lng, max_lat, max_lng = a
        scope = scope.where(latitude:  min_lat..max_lat,
                            longitude: min_lng..max_lng)
      end

    # OU rayon simple (approx) : lat,lng,radius (km)
    elsif params[:lat].present? && params[:lng].present? && params[:radius].present?
      lat  = params[:lat].to_f
      lng  = params[:lng].to_f
      r_km = params[:radius].to_f
      dlat = r_km / 111.0
      dlng = r_km / (Math.cos(lat * Math::PI / 180.0) * 111.0)
      scope = scope.where(latitude:  (lat - dlat)..(lat + dlat),
                          longitude: (lng - dlng)..(lng + dlng))
    end

    limit = (params[:limit].presence || 1000).to_i.clamp(1, 2000)

    rows = scope.limit(limit).select(
      :id, :title, :description, :category, :organization,
      :location, :time_commitment, :latitude, :longitude
    ).map { |o|
      {
        id: o.id,
        title: o.title,
        description: o.description,
        category: o.category,
        organization: o.organization,
        location: o.location,
        time_commitment: o.time_commitment,
        latitude:  o.latitude&.to_f,
        longitude: o.longitude&.to_f
      }
    }

    render json: rows
  rescue => e
    Rails.logger.error("[/api/v1/opportunities] #{e.class}: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end
end



