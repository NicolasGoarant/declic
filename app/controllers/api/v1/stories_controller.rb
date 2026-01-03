module Api
  module V1
    class StoriesController < ApplicationController
      def index
        # Filtrer uniquement les stories actives pour l'API
        stories = Story.where(is_active: true)
                       .where.not(latitude: nil, longitude: nil)
                       .order(happened_on: :desc, created_at: :desc)
                       .limit(100)

        render json: stories.map { |s|
          # Générer l'URL de l'image (Active Storage ou image_url)
          img_url = if s.image.attached?
                      rails_blob_url(s.image)
                    elsif s.image_url.present?
                      s.image_url
                    else
                      nil
                    end

          {
            id: s.id,
            title: s.title,
            chapo: s.chapo,
            description: s.description,
            location: s.location,
            latitude: s.latitude,
            longitude: s.longitude,
            happened_on: s.happened_on,
            category: 'histoires',
            url: story_url(s),
            image_url: img_url
          }
        }
      end
    end
  end
end
