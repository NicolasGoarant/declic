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

  def create
    @story = Story.new(story_params)

    if @story.save
      StoryProposalMailer.with(story: @story).proposal_email.deliver_later
      redirect_to merci_stories_path(name: @story.author_name)
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
      :title, :chapo, :content, :name, :email, :phone, :address, :city, :postal_code,
      photos: []
    ).tap do |whitelisted|
      # Mapper les champs du formulaire vers les colonnes DB
      whitelisted[:body] = whitelisted.delete(:content) if whitelisted[:content].present?
      whitelisted[:author_name] = whitelisted.delete(:name) if whitelisted[:name].present?
      whitelisted[:author_email] = whitelisted.delete(:email) if whitelisted[:email].present?

      # Sécurité : ne garder que les colonnes qui existent
      whitelisted.select! { |key| Story.column_names.include?(key.to_s) || key.to_s == "photos" }
    end
  end
end
