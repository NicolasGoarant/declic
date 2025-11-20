# app/mailers/opportunity_proposal_mailer.rb
class OpportunityProposalMailer < ApplicationMailer
  default to: "nicolas.goarant@hotmail.fr",
          from: "Déclic <no-reply@declic.local>"

  # Mail envoyé quand quelqu'un valide sa fiche "Proposer une opportunité"
  def proposal_email
    @opportunity = params[:opportunity]

mail(
  to: "nicolas.goarant@hotmail.fr", # ou l’adresse destinataire que tu veux
  from: ENV.fetch("DEFAULT_FROM_EMAIL", "nicolas.goarant@hotmail.fr"),
  subject: "Nouvelle opportunité proposée"
)

  end
end
