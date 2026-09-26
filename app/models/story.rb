class Story < ApplicationRecord
  include NancyGeocodable

  # Image principale (hero)
  has_one_attached :image

  # Galerie photos : ordre, couverture, suppressions (voir GaleriePhotos)
  include GaleriePhotos
  include FicheCompletude

  # Photos inline dans le récit (3 max pour style éditorial)
  # Ces images seront insérées dans le texte via des placeholders
  has_one_attached :inline_image_1
  has_one_attached :inline_image_2
  has_one_attached :inline_image_3

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true
  # Nouvelles fiches seulement : ne rend invalide aucune histoire existante.
  validates :location, presence: true, on: :create
  validate :points_forts_limites

  # « Ce qu'il faut retenir » : au plus 3 points {icone, titre, texte} (voir PointsForts).
  def points_forts_liste = PointsForts.normaliser(points_forts)

  # Saisie admin : trois blocs fixes {icone, titre, texte} ; les blocs vides sont ignorés.
  def points_forts_saisie
    liste = points_forts_liste
    Array.new(PointsForts::MAX) { |i| liste[i] || PointsForts::VIDE.dup }
  end

  def points_forts_saisie=(blocs)
    blocs = blocs.to_h.sort_by { |cle, _| cle.to_s.to_i }.map(&:last) if blocs.respond_to?(:to_h) && !blocs.is_a?(Array)
    self.points_forts = PointsForts.normaliser(blocs).first(PointsForts::MAX)
  end

  # Catégorie d'opportunité que l'histoire porte dans ses étiquettes (clé ou libellé,
  # « ecologiser », « Écologiser »…), sinon nil. Les histoires n'ont pas de colonne catégorie.
  def categorie_opportunite
    etiquettes = tags.to_s.split(/[;,]/).map { |t| t.strip.parameterize }
    Opportunity::CATEGORIES.find do |cle|
      etiquettes.include?(cle) || etiquettes.include?(Categorie.trouver(cle).libelle.parameterize)
    end
  end

  # « Des opportunités pour avoir ton déclic » : actives et pas terminées, de la catégorie de
  # l'histoire si elle en porte une, complétées par les plus proches géographiquement.
  def opportunites_proches(limite = 3)
    base = Opportunity.active.actuelles
    choix = categorie_opportunite ? base.where(category: categorie_opportunite).limit(limite).to_a : []
    return choix if choix.size >= limite

    reste = base.where.not(id: choix.map(&:id))
    if latitude.present? && longitude.present?
      reste = reste.with_coords.to_a.sort_by { |o| (o.latitude.to_f - latitude)**2 + ((o.longitude.to_f - longitude) * Math.cos(latitude * Math::PI / 180))**2 }
    end
    choix + reste.first(limite - choix.size)
  end

  # « D'autres belles histoires ».
  def autres_histoires(limite = 3)
    Story.active.where.not(id: id).order(happened_on: :desc, created_at: :desc).limit(limite)
  end

  # Champs que la nouvelle fiche affiche (voir FicheCompletude).
  def criteres_fiche
    {
      "photo" => a_une_photo?,
      "lieu" => location.present?,
      "citation" => quote.present?,
      "points forts" => points_forts_liste.any?,
      "source" => source_name.present? && source_url.present?
    }
  end

  # Configure la géolocalisation, restreinte à la zone de Nancy (voir
  # NancyGeocodable — même mécanisme que Opportunity).
  nancy_geocoded_by :location

  # Ne géocoder automatiquement que si coords manquantes ET location a changé
  before_validation :geocode_and_guard, if: -> {
    location.present? &&
    (latitude.blank? || longitude.blank?) &&
    will_save_change_to_location?
  }

  before_validation :ensure_slug

  # Par défaut, les nouvelles stories sont inactives (en attente de validation)
  before_validation :set_default_active, on: :create

  # Scope pour ne récupérer que les stories actives
  scope :active, -> { where(is_active: true) }

  # Choix d'image pour le front (upload > URL > fallback)
  def hero_image_url(view_context)
    if image.attached?
      view_context.url_for(image)
    elsif image_url.present?
      (image_url =~ /\Ahttp/i) ? image_url : view_context.asset_path(image_url)
    else
      view_context.asset_path("fallback-story.jpg") rescue ""
    end
  end

  # Vérifie si au moins une image inline est attachée
  def has_inline_images?
    inline_image_1.attached? || inline_image_2.attached? || inline_image_3.attached?
  end

  # Compte le nombre d'images inline attachées
  def inline_images_count
    count = 0
    count += 1 if inline_image_1.attached?
    count += 1 if inline_image_2.attached?
    count += 1 if inline_image_3.attached?
    count
  end

  private

  def ensure_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end

  def points_forts_limites
    return if points_forts.nil?
    return errors.add(:points_forts, "doit être une liste") unless points_forts.is_a?(Array)

    errors.add(:points_forts, ": #{PointsForts::MAX} au plus") if points_forts.size > PointsForts::MAX
  end

  def set_default_active
    self.is_active = false if is_active.nil?
  end
end
