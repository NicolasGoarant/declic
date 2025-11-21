# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")

  def proposal_email
    @opportunity = params[:opportunity]

    # === Ajout des pièces jointes ===
    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        attachments["photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content:   photo.download
        }
      end
    end

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    )
  end
end
