module Api
  module V1
    class OpportunitiesController < ApplicationController
      def index
        # Filtrer uniquement les opportunités actives
        opportunities = Opportunity.where(is_active: true)
                                   .where.not(latitude: nil, longitude: nil)
                                   .order(created_at: :desc)
                                   .limit(100)

        render json: opportunities.map { |o|
          # Générer l'URL de l'image (Active Storage ou image_url)
          img_url = if o.image.attached?
                      rails_blob_url(o.image)
                    elsif o.image_url.present?
                      o.image_url
                    else
                      nil
                    end

          {
            id: o.id,
            slug: o.slug,
            title: o.title,
            description: o.description,
            category: o.category,
            organization: o.organization,
            location: o.location,
            latitude: o.latitude,
            longitude: o.longitude,
            starts_at: o.starts_at,
            url: opportunity_url(o),
            image_url: img_url
          }
        }
      end

      def show
        @opportunity = Opportunity.find(params[:id])

        img_url = if @opportunity.image.attached?
                    rails_blob_url(@opportunity.image)
                  elsif @opportunity.image_url.present?
                    @opportunity.image_url
                  else
                    nil
                  end

        render json: {
          id: @opportunity.id,
          slug: @opportunity.slug,
          title: @opportunity.title,
          description: @opportunity.description,
          category: @opportunity.category,
          organization: @opportunity.organization,
          location: @opportunity.location,
          latitude: @opportunity.latitude,
          longitude: @opportunity.longitude,
          starts_at: @opportunity.starts_at,
          website: @opportunity.website,
          contact_email: @opportunity.contact_email,
          image_url: img_url
        }
      end
    end
  end
end
