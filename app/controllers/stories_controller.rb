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
    # Envoi du mail à l'équipe
    StoryProposalMailer.with(story: @story).proposal_email.deliver_later

    # Redirection vers la page merci au lieu de l'index
    redirect_to merci_opportunities_path
  else
    render :new, status: :unprocessable_entity
  end
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
