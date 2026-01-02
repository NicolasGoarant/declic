class StoriesController < ApplicationController
  def index
    @stories = Story.order(created_at: :desc)
  end

  def show
    @story = Story.find_by!(id: params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    @story ||= Story.find_by!(slug: params[:id])
  end

  def new
    @story = Story.new
  end

# app/controllers/stories_controller.rb

def create
  @story = Story.new(story_params)
  if @story.save
    StoryProposalMailer.with(story: @story).proposal_email.deliver_later
    # On passe le nom en paramètre pour la page Merci
    redirect_to merci_stories_path(name: @story.name)
  else
    render :new, status: :unprocessable_entity
  end
end

def merci
  @name = params[:name]
end

  private

  def story_params
    params.require(:story).permit(
      :title,
      :chapo,
      :body,
      :author_name,
      :author_email,
      :city,
      :contact_info,
      photos: []
    )
  end
end
