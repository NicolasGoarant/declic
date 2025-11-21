class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr")
  layout "mailer"
end

class OpportunityProposalMailer < ApplicationMailer
  default to: "nicolas.goarant@hotmail.fr"

  def proposal_email
    @opportunity = params[:opportunity]

    mail(
      to: "nicolas.goarant@hotmail.fr",
      from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr"),
      subject: "Nouvelle opportunité proposée"
    )
  end
end
