# app/controllers/api/v1/opportunities_controller.rb
class Api::V1::OpportunitiesController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    ops = Opportunity.where(is_active: true)
                     .select(:id, :title, :description, :category, :organization,
                             :location, :time_commitment, :latitude, :longitude)
    render json: ops.map { |o|
      o.as_json.merge(latitude: o.latitude.to_f, longitude: o.longitude.to_f)
    }
  end

  def show
    o = Opportunity.find(params[:id])
    render json: o.as_json.merge(latitude: o.latitude.to_f, longitude: o.longitude.to_f)
  end
end

