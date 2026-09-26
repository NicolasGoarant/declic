# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  before_action :http_basic_authenticate

  private

  # Identifiants absents ou vides -> 403 partout, développement compris : un admin
  # sans mot de passe configuré ne doit jamais s'ouvrir par erreur.
  def http_basic_authenticate
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
