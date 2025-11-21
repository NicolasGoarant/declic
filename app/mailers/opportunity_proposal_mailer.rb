class OpportunityProposalMailer < ApplicationMailer
  default to: "nicolas.goarant@hotmail.fr"

  def proposal_email
    @opportunity = params[:opportunity]

    # Pièces jointes
    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        attachments["photo_#{index + 1}#{File.extname(photo.filename.to_s)}"] = photo.download
      end
    end

    mail(
      subject: "Nouvelle opportunité proposée",
      from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")
    )
  end
end
