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
      # On redirige avec le nom pour le message personnalisé
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
    # 1. On autorise tout ce qui vient du formulaire
    params.require(:story).permit(
      :title, :chapo, :content, :name, :email, :phone, :address, photos: []
    ).tap do |whitelisted|
      # 2. On branche les champs du formulaire sur les vraies colonnes de votre DB
      whitelisted[:body] = whitelisted.delete(:content) if whitelisted[:content].present?
      whitelisted[:author_name] = whitelisted.delete(:name) if whitelisted[:name].present?
      whitelisted[:author_email] = whitelisted.delete(:email) if whitelisted[:email].present?

      # 3. Sécurité : On ne garde que ce qui existe VRAIMENT dans la table stories
      # Cela empêchera toute erreur "UnknownAttributeError" quoi qu'il arrive
      whitelisted.select! { |key| Story.column_names.include?(key.to_s) || key.to_s == "photos" }
    end
  end
end
