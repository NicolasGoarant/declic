# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  before_action :http_basic_authenticate

  private

def http_basic_authenticate
    # app/controllers/admin/base_controller.rb
# Ligne 7 :
user = ENV.fetch("ADMIN_USERNAME", nil) # CORRIGÉ
    pass = ENV.fetch("ADMIN_PASSWORD", nil)
    # ...

    # Si identifiants non configurés -> autoriser en dev, protéger en prod
    return if Rails.env.development? && user.blank? && pass.blank?

    authenticate_or_request_with_http_basic("Admin Déclic") do |u, p|
      ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) &&
        ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
    end
  end
end
