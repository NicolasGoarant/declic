class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info "[MAILER] Opportunity #{@opportunity.id} " \
                      "photos.attached?=#{@opportunity.photos.attached?} " \
                      "count=#{@opportunity.photos.count}"

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        Rails.logger.info "[MAILER] attaching photo #{index+1} : #{photo.filename} (#{photo.byte_size} bytes)"

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
