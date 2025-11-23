class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@declic.app")

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info("MAILER DEBUG: entering proposal_email")
    Rails.logger.info("MAILER DEBUG: opportunity id=#{@opportunity&.id.inspect} class=#{@opportunity.class.name}")

    if @opportunity.respond_to?(:photos)
      Rails.logger.info("MAILER DEBUG: @opportunity.photos.attached?=#{@opportunity.photos.attached?.inspect}")
      Rails.logger.info("MAILER DEBUG: @opportunity.photos.size=#{@opportunity.photos.size}")
    else
      Rails.logger.info("MAILER DEBUG: @opportunity does not respond_to? :photos")
    end

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        Rails.logger.info("MAILER DEBUG: attaching photo ##{index + 1} - " \
                          "filename=#{photo.filename}, content_type=#{photo.blob.content_type}, " \
                          "byte_size=#{photo.blob.byte_size}")

        attachments["opportunity_#{@opportunity.id}_photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content: photo.blob.download
        }
      end
    else
      Rails.logger.info("MAILER DEBUG: no photos attached to opportunity")
    end

    Rails.logger.info("MAILER DEBUG: attachments keys before mail: #{attachments.keys}")

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    ) do |format|
      format.html
    end
  end
end
