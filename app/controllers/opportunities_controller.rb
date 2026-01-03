# frozen_string_literal: true

class OpportunitiesController < ApplicationController
  # Liste des opportunités publiques (uniquement les actives)
  def index
    @opportunities = Opportunity.active.order(created_at: :desc).limit(100)
  end

  # Affichage d'une opportunité via son slug (FriendlyId)
  def show
    @opportunity = Opportunity.friendly.find(params[:id])
  end

  # Formulaire de proposition (Public)
  # Correction : Initialisation explicite de l'objet pour éviter les erreurs nil dans la vue
  def new
    @opportunity = Opportunity.new
  end

  # Action de création (Soumission du formulaire public)
  def create
    @opportunity = Opportunity.new(opportunity_params)

    # Sécurité : On force is_active à false pour que l'équipe admin doive valider
    @opportunity.is_active = false

    if @opportunity.save
      # Envoi de l'email à Mailtrap/Production avec les pièces jointes
      # deliver_later est préférable pour ne pas bloquer l'utilisateur pendant l'upload S3
      OpportunityProposalMailer.with(opportunity: @opportunity).proposal_email.deliver_later

      redirect_to merci_opportunities_path
    else
      # En cas d'erreur (ex: adresse manquante), on réaffiche le formulaire
      flash.now[:alert] = "Veuillez corriger les erreurs ci-dessous."
      render :new, status: :unprocessable_entity
    end
  end

  # Page de succès après envoi
  def merci
  end

  private

  # CORRECTION CRITIQUE : Autorisation des paramètres
  # 1. Ajout de :address, :city, :postal_code pour correspondre à votre formulaire
  # 2. Ajout de photos: [] (avec S et crochets) pour accepter le tableau de fichiers
  def opportunity_params
    params.require(:opportunity).permit(
      :title,
      :description,
      :category,
      :organization,
      :location,
      :address,
      :city,
      :postal_code,
      :contact_email,
      :website,
      photos: []
    )
  end
end
