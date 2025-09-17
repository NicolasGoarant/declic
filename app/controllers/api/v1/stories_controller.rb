# app/controllers/api/v1/stories_controller.rb
class Api::V1::StoriesController < ApplicationController
  def index
    stories = Story.where.not(latitude: nil, longitude: nil).order(created_at: :desc).limit(500)
    render json: stories.map { |s|
      {
        id: s.id,
        slug: s.respond_to?(:slug) ? s.slug : nil,
        title: s.title,
        description: s.try(:chapo).presence || s.try(:description).to_s,
        category: "histoires",                # important pour le marker violet 📖
        organization: s.try(:source_name).to_s,
        location: s.location.to_s,
        latitude: s.latitude.to_f,
        longitude: s.longitude.to_f
      }
    }
  end
end
