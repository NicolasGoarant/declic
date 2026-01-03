class StoriesController < ApplicationController
  def index
    # Filtrer uniquement les stories actives
    @stories = Story.where(is_active: true)
                    .order(happened_on: :desc, created_at: :desc)
                    .limit(100)
  end

  def show
    @story = Story.find_by!(id: params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    @story ||= Story.find_by!(slug: params[:id])

    # Rediriger si la story n'est pas active (sauf pour les admins)
    # Optionnel : enlève ce check si tu veux permettre l'aperçu via lien direct
    unless @story.is_active
      redirect_to stories_path, alert: "Cette histoire n'est pas encore publiée."
    end
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
      whitelisted[:body] = whitelisted.delete(:content) if whitelisted[:content].present?
      whitelisted[:author_name] = whitelisted.delete(:name) if whitelisted[:name].present?
      whitelisted[:author_email] = whitelisted.delete(:email) if whitelisted[:email].present?

      whitelisted.select! { |key| Story.column_names.include?(key.to_s) || key.to_s == "photos" }
    end
  end
end
