class Story < ApplicationRecord
  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  before_validation :ensure_slug

  def to_param
    slug.presence || super
  end

  private

  def ensure_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end
end
