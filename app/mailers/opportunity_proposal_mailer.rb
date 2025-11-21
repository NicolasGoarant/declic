# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info "[MAILER] Opportunity #{@opportunity.id} – photos.attached?=#{@opportunity.photos.attached?} count=#{@opportunity.photos.size}"

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        Rails.logger.info "[MAILER] Attaching photo #{index + 1}: #{photo.filename} (#{photo.blob.byte_size} bytes, #{photo.blob.content_type})"

        attachments["photo_#{index + 1}_#{photo.filename}"] = {
          mime_type: photo.blob.content_type,
          content:   photo.download
        }
      end
    end

    Rails.logger.info "[MAILER] Attachments keys in mailer: #{attachments.keys.inspect}"

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    )
  end
end
