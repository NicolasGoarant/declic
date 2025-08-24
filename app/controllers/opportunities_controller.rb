class OpportunitiesController < ApplicationController
  def show
    @opportunity = Opportunity.find(params[:id])
  end
end
