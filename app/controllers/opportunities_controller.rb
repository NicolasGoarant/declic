class OpportunitiesController < ApplicationController
def show
  # app/controllers/opportunities_controller.rb
@opportunity = Opportunity.friendly.find(params[:id])

end
end
