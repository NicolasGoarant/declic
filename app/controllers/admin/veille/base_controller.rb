# frozen_string_literal: true

module Admin
  module Veille
    # Réutilise l'authentification admin existante (HTTP Basic sur
    # ADMIN_USERNAME / ADMIN_PASSWORD, définie dans Admin::BaseController).
    #
    # Layout dédié : le layout applicatif porte data-turbo="false" et le
    # layout admin ne charge aucun JavaScript. Ni l'un ni l'autre ne permet
    # les Turbo Streams dont cette interface a besoin.
    class BaseController < Admin::BaseController
      layout "veille"

      # Review App Heroku de consultation uniquement : l'authentification est levée
      # si REVIEW_APP_SANS_AUTH=1 ET si Heroku signale une review app (HEROKU_PR_NUMBER,
      # posé par Heroku seul). Jamais actif en production.
      skip_before_action :http_basic_authenticate, if: :review_app_ouverte?

      private

      def review_app_ouverte?
        ENV["REVIEW_APP_SANS_AUTH"] == "1" && ENV["HEROKU_PR_NUMBER"].present?
      end
    end
  end
end
