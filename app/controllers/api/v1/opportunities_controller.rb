class Api::V1::OpportunitiesController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    scope = Opportunity.where(is_active: true)

    # Filtre catégorie (?category=benevolat ou ?category=benevolat,formation)
    if params[:category].present?
      cats = Array(params[:category])
               .flat_map { |c| c.to_s.split(',') }
               .map(&:strip).reject(&:blank?)
      scope = scope.where(category: cats) if cats.any?
    end

    # BBOX: minLat,minLng,maxLat,maxLng
    if params[:bbox].present?
      a = params[:bbox].to_s.split(',').map(&:to_f)
      if a.size == 4
        min_lat, min_lng, max_lat, max_lng = a
        scope = scope.where(latitude: min_lat..max_lat, longitude: min_lng..max_lng)
      end
    # OU rayon simple: lat,lng,radius (km)
    elsif params[:lat].present? && params[:lng].present? && params[:radius].present?
      lat  = params[:lat].to_f
      lng  = params[:lng].to_f
      r_km = params[:radius].to_f
      dlat = r_km / 111.0
      dlng = r_km / (Math.cos(lat * Math::PI / 180.0) * 111.0)
      scope = scope.where(latitude: (lat - dlat)..(lat + dlat),
                          longitude: (lng - dlng)..(lng + dlng))
    end

    limit = (params[:limit].presence || 1000).to_i.clamp(1, 2000)

    # IMPORTANT : Précharger l'attachment image pour Active Storage
    opportunities = scope.includes(image_attachment: :blob).limit(limit)

    rows = opportunities.map { |o|
      # PRIORITÉ : Active Storage > image_url
      final_image_url = if o.image.attached?
                          url_for(o.image)
                        elsif o.image_url.present?
                          o.image_url
                        else
                          nil
                        end

      {
        id:             o.id,
        slug:           o.slug,
        title:          o.title,
        description:    o.description,
        category:       o.category,
        organization:   o.organization,
        location:       o.location,
        time_commitment:o.time_commitment,
        latitude:       o.latitude&.to_f,
        longitude:      o.longitude&.to_f,
        image_url:      final_image_url
      }
    }

    render json: rows
  rescue => e
    Rails.logger.error("[/api/v1/opportunities] #{e.class}: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end
end
