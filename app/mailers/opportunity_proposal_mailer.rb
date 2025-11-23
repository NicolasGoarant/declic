class OpportunityProposalMailer < ApplicationMailer
  # Adapte si besoin, mais c'est ce qui apparaît déjà dans tes logs
  default to:   "nicolas.goarant@hotmail.fr",
          from: "nicolas.goarant@hotmail.fr"

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info("[OPP MAILER] opportunity id=#{@opportunity&.id} " \
                      "photos_attached?=#{@opportunity.photos.attached?} " \
                      "photos_size=#{@opportunity.photos.size}")

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        Rails.logger.info("[OPP MAILER] attaching photo ##{index + 1} " \
                          "filename=#{photo.filename} " \
                          "content_type=#{photo.blob.content_type} " \
                          "byte_size=#{photo.blob.byte_size}")

        attachments["opportunity_#{@opportunity.id}_photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content: photo.blob.download
        }
      end
    else
      Rails.logger.info("[OPP MAILER] no photos attached to opportunity")
    end

    Rails.logger.info("[OPP MAILER] attachments keys before mail: #{attachments.keys.inspect}")

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    ) do |format|
      format.html
    end
  end
end
