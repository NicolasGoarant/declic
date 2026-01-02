class StoryProposalMailer < ApplicationMailer
  # Configurez l'adresse de réception et l'expéditeur par défaut
  default to: "nicolas.goarant@hotmail.fr",
          from: "nicolas.goarant@hotmail.fr"

  def proposal_email
    @story = params[:story]

    # Pièces jointes : on attache les photos envoyées par l'utilisateur
    if @story.photos.attached?
      @story.photos.each_with_index do |photo, index|
        attachments["photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content: photo.blob.download
        }
      end
    end

    mail(
      subject: "Nouveau témoignage Déclic : #{@story.title.presence || 'Sans titre'}"
    )
  end
end
