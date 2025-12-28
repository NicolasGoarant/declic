# app/controllers/api/v1/stories_controller.rb
class Api::V1::StoriesController < ApplicationController
  def index
    stories = Story.where.not(latitude: nil, longitude: nil).order(created_at: :desc).limit(500)
    render json: stories.map { |s|
      # PRIORITÉ : Active Storage > image_url
      final_image_url = if s.respond_to?(:image) && s.image.attached?
                          url_for(s.image) rescue nil
                        elsif s.respond_to?(:image_url)
                          s.image_url
                        else
                          nil
                        end

      {
        id: s.id,
        slug: s.respond_to?(:slug) ? s.slug : nil,
        title: s.title,
        description: s.try(:chapo).presence || s.try(:description).to_s,
        category: "histoires",                # important pour le marker violet 📖
        organization: s.try(:source_name).to_s,
        location: s.location.to_s,
        latitude: s.latitude.to_f,
        longitude: s.longitude.to_f,
        image_url: final_image_url
      }
    }
  end
end
