class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@declic.app")

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info "[MAILER] >>> ENTER proposal_email for opportunity #{@opportunity.id}"
    Rails.logger.info "[MAILER] photos.attached?=#{@opportunity.photos.attached?} count=#{@opportunity.photos.size}"

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        begin
          Rails.logger.info "[MAILER] Photo #{index + 1}: filename=#{photo.filename} " \
                            "blob_id=#{photo.blob.id} size=#{photo.blob.byte_size} type=#{photo.blob.content_type}"

          data = photo.download
          Rails.logger.info "[MAILER] Photo #{index + 1}: downloaded #{data.bytesize} bytes"

          filename = "opportunity_#{@opportunity.id}_photo_#{index + 1}_#{photo.filename}"
          attachments[filename] = {
            mime_type: photo.blob.content_type,
            content: data
          }

          Rails.logger.info "[MAILER] Photo #{index + 1}: attached as #{filename}"
        rescue => e
          Rails.logger.error "[MAILER] ERROR while attaching photo #{index + 1}: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    else
      Rails.logger.info "[MAILER] No photos attached to opportunity #{@opportunity.id}"
    end

    Rails.logger.info "[MAILER] Final attachments keys in mailer method: #{attachments.keys.inspect}"

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    ) do |format|
      format.html
    end
  end
end
