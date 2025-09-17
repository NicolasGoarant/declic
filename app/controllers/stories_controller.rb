# app/controllers/stories_controller.rb
class StoriesController < ApplicationController
  def index
    @stories = Story.order(created_at: :desc).limit(36)
    # Si un paramètre ?category= est passé, on peut l’exploiter plus tard pour filtrer par tag.
  end

  def show
    @story = Story.find_by(slug: params[:id]) || Story.find(params[:id])
  end
end
