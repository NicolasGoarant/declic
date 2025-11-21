class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "declic.application@gmail.com")

  def proposal_email
    @opportunity = params[:opportunity]

    # Joindre les photos si présentes
    if @opportunity.photos.attached?
      @opportunity.photos.each do |photo|
        attachments[photo.filename.to_s] = {
          mime_type: photo.content_type,
          content:   photo.download
        }
      end
    end

    mail(
      to:      "nicolas.goarant@hotmail.fr",
      subject: "Nouvelle opportunité proposée"
    )
  end
end
