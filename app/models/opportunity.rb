# app/models/opportunity.rb
class Opportunity < ApplicationRecord
  # -------- FriendlyId (URLs lisibles) --------
  extend FriendlyId
  friendly_id :title, use: %i[slugged finders]

  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_title?
  end

  # -------- Geocoder (requêtes par rayon) --------
  # Déclare les colonnes lat/lng et active les helpers Geocoder
  include Geocoder::Model::ActiveRecord
  reverse_geocoded_by :latitude, :longitude
  # (Si tu veux calculer l’adresse à partir lat/lng : ajoute un after_validation :reverse_geocode)

  # -------- Constantes / validations --------
  CATEGORIES = %w[benevolat formation rencontres entreprendre].freeze

  validates :title, presence: true, length: { maximum: 180 }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :latitude, numericality: true, allow_nil: true
  validates :longitude, numericality: true, allow_nil: true

  # -------- Scopes de filtre --------
  scope :active, -> { where(is_active: true) }

  scope :with_category, ->(cat) {
    cat.present? ? where(category: cat) : all
  }

  # Recherche simple et DB-agnostique (SQLite / PG)
  scope :search_text, ->(q) {
    next all unless q.present?
    term = "%#{sanitize_sql_like(q.to_s.downcase)}%"
    where(
      "LOWER(title) LIKE :t OR LOWER(description) LIKE :t OR LOWER(organization) LIKE :t OR LOWER(location) LIKE :t",
      t: term
    )
  }

  # Requête par rayon (km) autour d’un point (lat, lng)
  scope :near_ll, ->(lat, lng, radius_km = 25) {
    if lat.present? && lng.present?
      near([lat.to_f, lng.to_f], radius_km.to_f, units: :km)
    else
      all
    end
  }

  # -------- Helpers --------
  # Retourne un tableau de tags à partir d'une chaîne "a, b; c"
  def tag_list
    tags.to_s.split(/[;,]/).map { _1.strip }.reject(&:blank?)
  end
end


