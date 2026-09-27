# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  # Compteurs affichés sur les pages éditoriales : ils doivent refléter
  # la base, pas des chiffres saisis à la main.
  before_action :load_public_counts, only: %i[presse]

  def home
    # Ce header complète la désactivation des previews si un proxy/cdn est devant
    response.set_header("Turbo-Visit-Control", "reload")

    @journey_cards = [
      { id: 1, category: 'benevolat',    title: 'Je veux aider',
        description: 'Trouvez des missions de bénévolat qui correspondent à vos valeurs',
        icon: 'heart',     color: 'bg-gradient-to-br from-red-500 to-pink-600' },
      { id: 2, category: 'formation',    title: 'Je veux apprendre',
        description: 'Découvrez des formations pour développer vos compétences',
        icon: 'book-open', color: 'bg-gradient-to-br from-blue-500 to-indigo-600' },
      { id: 3, category: 'rencontres',   title: 'Je veux rencontrer',
        description: 'Rejoignez des communautés et créez des liens authentiques',
        icon: 'users',     color: 'bg-gradient-to-br from-green-500 to-teal-600' },
      { id: 4, category: 'entreprendre', title: 'Je veux entreprendre',
        description: "Lancez votre projet avec le soutien d'entrepreneurs expérimentés",
        icon: 'briefcase', color: 'bg-gradient-to-br from-orange-500 to-red-600' }
    ]

    # Toutes les opportunities actives, triées par date de création décroissante (les plus récentes en premier)
    @opportunities = Opportunity.where(is_active: true).order(created_at: :desc)

    # Les 3 dernières opportunities (basées sur published_at)
    @latest = Opportunity.active.order(published_at: :desc).limit(3)
  end

  def legal; end
  def confidentialite; end
  def presse; end
  def sponsors; end
  def faq; end
  def contact; end

  # « Pourquoi Déclic ? » : même habillage que les fiches (layout « fiche », barre de /labo/accueil).
  def philosophie
    @chiffres = Rails.cache.fetch("pourquoi/chiffres", expires_in: 10.minutes) do
      { opportunites: Opportunity.active.count, histoires: Story.active.count }
    end
    @collage = COLLAGE.map { |cle, repli, alt| { categorie: Categorie.trouver(cle), photo: photo_de_categorie(cle) || { src: repli, alt: alt } } }
    @pins_territoire = pins_territoire
    render layout: "fiche"
  end

  private

  # Collage « Un déclic peut tout changer » : catégorie, photo de repli (sans visage reconnaissable), texte alternatif.
  COLLAGE = [
    [ "formation", "pourquoi/se-former.webp", "Mains qui peignent des figurines en céramique lors d'un atelier" ],
    [ "benevolat", "pourquoi/s-engager.webp", "Jardin avec pelouse et haie devant une maison" ],
    [ "entreprendre", "pourquoi/entreprendre.webp", "Espace de travail partagé où des personnes échangent" ],
    [ "rencontres", "pourquoi/rencontrer.webp", "Atelier d'artisanat partagé où plusieurs personnes travaillent" ]
  ].freeze
  PINS_TERRITOIRE = %w[ecologiser benevolat rencontres formation].freeze

  # Une vraie opportunité par catégorie, dans la Métropole, choisie pour écarter les pins les uns des
  # autres (et du centre) : chaque choix maximise sa distance au plus proche des points déjà posés.
  def pins_territoire
    poses = [ PourquoiCarte::CENTRE ]
    PINS_TERRITOIRE.filter_map do |cle|
      candidates = Opportunity.active.with_coords.where(category: cle).order(:id)
                              .select { |o| PourquoiCarte.dans_la_metropole?(o.longitude, o.latitude) }
      o = candidates.max_by do |op|
        poses.map { |lon, lat| Math.hypot((op.longitude.to_f - lon) * 0.66, op.latitude.to_f - lat) }.min
      end
      next unless o
      poses << [ o.longitude.to_f, o.latitude.to_f ]
      { categorie: Categorie.trouver(cle), opportunite: o }
    end
  end

  # Photo de couverture d'une opportunité active (puis d'une histoire) de la catégorie, ou nil.
  def photo_de_categorie(cle)
    fiche = Opportunity.active.where(category: cle).joins(:image_attachment).order(updated_at: :desc).first ||
            Story.active.joins(:image_attachment).order(updated_at: :desc).limit(50).find { |s| s.categorie_opportunite == cle }
    fiche && { src: url_for(fiche.image), alt: fiche.title }
  end

  def load_public_counts
    @opportunities_count = Opportunity.active.count
    @stories_count       = Story.active.count
  end
end
