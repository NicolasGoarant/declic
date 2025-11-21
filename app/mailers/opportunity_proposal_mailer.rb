# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  # adapte si besoin, mais peu importe pour le debug
  default to:   "nicolas.goarant@hotmail.fr",
          from: ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@declic.app")

  def proposal_email
    @opportunity = params[:opportunity]

    Rails.logger.info "[MAILER] OpportunityProposalMailer#proposal_email for opportunity #{@opportunity.id}"
    Rails.logger.info "[MAILER] photos.attached?=#{@opportunity.photos.attached?} count=#{@opportunity.photos.size}"

    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        Rails.logger.info "[MAILER] Attaching photo #{index + 1}: #{photo.filename} " \
                          "(#{photo.blob.byte_size} bytes, #{photo.blob.content_type})"

        # Version simple : on met juste le binaire du fichier
        attachments["photo_#{index + 1}_#{photo.filename}"] = photo.download
      end
    end

    Rails.logger.info "[MAILER] Final attachments keys: #{attachments.keys.inspect}"

    mail(
      subject: "Nouvelle opportunité proposée – #{@opportunity.title.presence || 'Sans titre'}"
    ) do |format|
      format.html # utilise app/views/opportunity_proposal_mailer/proposal_email.html.erb
    end
  end
end
