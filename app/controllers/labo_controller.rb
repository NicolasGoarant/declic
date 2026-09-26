# Pages de test isolées, sans lien depuis la navigation publique.
class LaboController < ApplicationController
  # Page autonome (sans layout) : le visualiseur n'a besoin ni de Leaflet ni de Turbo.
  def diorama
    response.set_header("X-Robots-Tag", "noindex, nofollow")
    render layout: false
  end
end
