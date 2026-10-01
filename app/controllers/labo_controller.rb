# Pages de test isolées, sans lien depuis la navigation publique.
class LaboController < ApplicationController
  # L'accueil est la page racine du site : elle seule est indexable.
  before_action(except: :accueil) { response.set_header("X-Robots-Tag", "noindex, nofollow") }

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
    @tuiles = DioramaTuiles.new
    # Les blocs sous la carte (maquette docs/maquettes/maquette-accueil-2026-09-30.png).
    @temoignages = temoignages_accueil
    # Agenda : de quoi remplir la vedette et quatre lignes pour chaque catégorie filtrée.
    @prochaines = Opportunity.active.prochaines.with_attached_photos.with_attached_image.limit(40)
    @une = Story.pour_la_une(1).first
    @histoires_accueil = Story.active.where.not(id: @une&.id).order(happened_on: :desc, created_at: :desc).limit(2).with_attached_image
    @chiffres = chiffres_impact
    @passages = PassagePresse.visibles
    render layout: "accueil"
  end

  # Page Opportunités (maquette declic-maquette-opportunites-v1) : uniquement des opportunités,
  # jamais de Belles Histoires (règle éditoriale, voir NOTES.md).
  def opportunites
    @opportunites = Opportunity.active.with_coords.with_attached_image.order(created_at: :desc)
    @tuiles = DioramaTuiles.new
    render layout: "fiche"
  end

  # Page Belles Histoires (maquette declic-maquette-belles-histoires-v1).
  def belles_histoires
    @histoires = Story.active.with_attached_image.order(happened_on: :desc, created_at: :desc)
    @tuiles = DioramaTuiles.new
    render layout: "fiche"
  end

  private

  # Bloc Témoignages : contenu éditorial de config/temoignages.yml (pas de modèle). Les entrées de
  # démonstration (`placeholder`) ne sortent jamais en production.
  def temoignages_accueil
    entrees = YAML.safe_load_file(Rails.root.join("config/temoignages.yml"), symbolize_names: true)
    entrees = entrees.reject { |t| t[:placeholder] } if Rails.env.production?
    entrees.map { |t| t.merge(role: [ t[:profession], t[:ville] ].compact_blank.join(" • ")) }
  end

  # « L'impact local » : des comptages de la base, jamais des chiffres saisis à la main. Sans
  # comptes utilisateurs, les « personnes engagées » sont celles que la base connaît par leur nom :
  # structures qui portent une opportunité et personnes des Belles Histoires.
  def chiffres_impact
    noms = Opportunity.active.where.not(organization: [ nil, "" ]).distinct.pluck(:organization) +
           Story.active.pluck(:quote_author, :author_name).flatten
    # Initiatives, rencontres et histoires : publiées ET placées sur la carte, comme le badge des
    # catégories (une fiche hors de la Métropole n'est pas comptée).
    actives = Opportunity.active.dans_la_zone
    {
      initiatives: actives.count,
      personnes: noms.compact_blank.map { |n| n.strip.downcase }.uniq.size,
      rencontres: actives.where(category: "rencontres").count,
      histoires: Story.active.dans_la_zone.count
    }
  end
end
