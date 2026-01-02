# app/mailers/opportunity_proposal_mailer.rb

class OpportunityProposalMailer < ApplicationMailer
  # Configuration de l'expéditeur et du destinataire par défaut
  default to:   "nicolas.goarant@hotmail.fr",
          from: "nicolas.goarant@hotmail.fr"

  def proposal_email
    @opportunity = params[:opportunity]

    # Log pour le débogage dans la console
    Rails.logger.info("[MAILER] Tentative d'envoi pour l'opportunité : #{@opportunity.title}")

    # Gestion des pièces jointes (photos)
    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        attachments["photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content: photo.blob.download
        }
      end
    end

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    )
  end
end
