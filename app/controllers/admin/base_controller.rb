# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  # Un seul habillage pour toute l'administration : barre sombre de la Veille.
  layout "veille"

  before_action :http_basic_authenticate

  private

  # Retour demandé par l'écran d'origine (galerie avec ses filtres et sa page) : chemin
  # interne à /admin uniquement, jamais une adresse extérieure.
  def retour_admin(defaut)
    retour = params[:retour].to_s
    retour.match?(%r{\A/admin(/|\?|\z)}) && !retour.start_with?("//") ? retour : defaut
  end
  helper_method :retour_admin

  # Interrupteur local : authentification sautée seulement en développement ET si
  # ADMIN_SANS_MOT_DE_PASSE=1 (.env local). Toute autre combinaison la conserve.
  def admin_sans_mot_de_passe?
    Rails.env.development? && ENV["ADMIN_SANS_MOT_DE_PASSE"] == "1"
  end

  # Identifiants absents ou vides -> 403 partout, développement compris : un admin
  # sans mot de passe configuré ne doit jamais s'ouvrir par erreur.
  def http_basic_authenticate
    return if admin_sans_mot_de_passe?

    user = ENV["ADMIN_USERNAME"].to_s
    pass = ENV["ADMIN_PASSWORD"].to_s
    return head(:forbidden) if user.empty? || pass.empty?

    authenticate_or_request_with_http_basic("Admin Déclic") do |u, p|
      # & et non && : les deux comparaisons ont toujours lieu (temps constant).
      ActiveSupport::SecurityUtils.secure_compare(u.to_s, user) &
        ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass)
    end
  end
end
