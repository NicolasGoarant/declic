# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  # où tu veux recevoir les mails
  default to: "nicolas.goarant@hotmail.fr"

  # Mail envoyé quand quelqu’un valide sa fiche "Proposer une opportunité"
  def proposal_email
    @opportunity = params[:opportunity]

    # Joindre les photos de l’opportunité (s’il y en a)
    if @opportunity.photos.attached?
      @opportunity.photos.each_with_index do |photo, index|
        # photo.download lit le fichier depuis Active Storage
        attachments["photo_#{index + 1}#{File.extname(photo.filename.to_s)}"] = photo.download
      end
    end

    mail(
      subject: "Nouvelle opportunité proposée",
      from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")
    )
  end
end
