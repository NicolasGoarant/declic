class Story < ApplicationRecord
  # Image principale (hero)
  has_one_attached :image

  # Cette ligne permet à Story d'accepter plusieurs fichiers via Active Storage
  has_many_attached :photos
  # Photos inline dans le récit (3 max pour style éditorial)
  has_one_attached :inline_image_1
  has_one_attached :inline_image_2
  has_one_attached :inline_image_3

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  # Configure la géolocalisation
  geocoded_by :location

  # ✅ Modif demandée : ne géocoder automatiquement que si coords manquantes
  before_validation :geocode, if: -> { location.present? && (latitude.blank? || longitude.blank?) && will_save_change_to_location? }

  before_validation :ensure_slug

  # ✅ Par défaut, les nouvelles stories sont inactives (en attente de validation)
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

  private

  def ensure_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end

  def set_default_active
    self.is_active = false if is_active.nil?
  end
end
