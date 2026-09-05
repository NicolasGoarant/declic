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
    end
  end
end
