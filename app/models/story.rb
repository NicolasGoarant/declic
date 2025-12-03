class Story < ApplicationRecord
  # Image principale
  has_one_attached :image

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  before_validation :ensure_slug

  def to_param
    slug.presence || super
  end

  # Choix d’image pour le front (upload > URL > fallback)
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
end
