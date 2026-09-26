# Pages de test isolées, sans lien depuis la navigation publique.
class LaboController < ApplicationController
  before_action { response.set_header("X-Robots-Tag", "noindex, nofollow") }

  # Page autonome (sans layout) : le visualiseur n'a besoin ni de Leaflet ni de Turbo.
  def diorama
    render layout: false
  end

  # Future page d'accueil construite sur le diorama (maquette v3 de nancy-3d). La page
  # d'accueil publique (pages#home) n'en dépend pas.
  #
  # Les points sont passés dans un attribut data de la page plutôt que par un endpoint :
  # une centaine de fiches pèse quelques dizaines de Ko, la carte les a dès le premier
  # rendu (pas de seconde requête, pas d'état « chargement »), et l'API publique
  # /api/v1/opportunities, limitée à 100 fiches et sans les dates saisies, reste inchangée.
  def accueil
    @opportunites = Opportunity.active.with_coords.with_attached_image.order(:id)
    @histoires_carte = Story.active.where.not(latitude: nil, longitude: nil).with_attached_image.order(:id)
    @histoires = Story.active.with_attached_image.order(happened_on: :desc).limit(6)
    @tuiles = DioramaTuiles.new
    render layout: "accueil"
  end
end
