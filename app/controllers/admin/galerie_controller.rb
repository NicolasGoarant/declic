# frozen_string_literal: true

module Admin
  # Galerie : fiches en ligne et candidats de la veille, vus ensemble. Même protection que /admin/veille
  # (hérite de Admin::Veille::BaseController : Basic auth, layout avec Turbo). Les actions des cartes
  # pointent vers celles de Admin::Veille::CandidatesController.
  class GalerieController < Admin::Veille::BaseController
    def index
      @galerie = ::Galerie.new(params)
    end
  end
end
