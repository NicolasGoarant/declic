class StoriesController < ApplicationController
  def index
    @stories = Story.order(created_at: :desc)
  end

  def show
    @story = Story.find_by!(slug: params[:id])
  end

  def new
    @story = Story.new
  end

  def create
    @story = Story.new(story_params)

    if @story.save
      StoryProposalMailer.with(story: @story).proposal_email.deliver_later
      redirect_to stories_path,
                  notice: "Merci ! Votre témoignage a bien été envoyé à l’équipe Déclic."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def story_params
    params.require(:story).permit(
      :title,
      :excerpt,
      :body,
      :author_name,
      :author_email,
      :city,
      :contact_info,
      photos: []
    )
  end
end
