class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@declic.app")

  def proposal_email
    @opportunity = params[:opportunity]

    # On ajoute les pièces jointes AVANT l'appel à `mail`
    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        attachments["opportunity_#{@opportunity.id}_photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content: photo.blob.download
        }
      end
    end

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    ) do |format|
      format.html
    end
  end
end
