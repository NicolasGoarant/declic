# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  default to: "nicolas.goarant@hotmail.fr",
          from: "Déclic <no-reply@declic.local>"

  # Mail envoyé quand quelqu'un valide sa fiche "Proposer une opportunité"
  def proposal_email
    @opportunity = params[:opportunity]

mail(
  to: ["nicolas.goarant@hotmail.fr", "nicolas.goarant35@gmail.com"],
  subject: "Nouvelle opportunité proposée"
)


  end
end
