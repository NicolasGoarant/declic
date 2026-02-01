class Story < ApplicationRecord
  # Image principale (hero)
  has_one_attached :image

  # Photos multiples pour soumissions publiques (si besoin futur)
  has_many_attached :photos

  # Photos inline dans le récit (3 max pour style éditorial)
  # Ces images seront insérées dans le texte via des placeholders
  has_one_attached :inline_image_1
  has_one_attached :inline_image_2
  has_one_attached :inline_image_3

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  # Configure la géolocalisation
  geocoded_by :location

  # Ne géocoder automatiquement que si coords manquantes ET location a changé
  before_validation :geocode, if: -> {
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

  def set_default_active
    self.is_active = false if is_active.nil?
  end
end
