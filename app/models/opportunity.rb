# app/models/opportunity.rb
class Opportunity < ApplicationRecord
  # Stockage JSON (SQLite/Postgres) – optionnel
   serialize :raw_payload, coder: JSON

  extend FriendlyId
  friendly_id :title, use: %i[slugged finders]
  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_title?
  end
  
    # Filtre pratique pour les enregistrements publiés
  scope :active, -> { where(is_active: true) }

  # ---- Catégories ----
  CATEGORIES = %w[benevolat formation rencontres entreprendre].freeze

  # ---- Géocodage (adresse -> lat/lng) ----
  reverse_geocoded_by :latitude, :longitude
  before_validation :geocode_if_needed

  # ---- Anti-spam (honeypot) ----
  attr_accessor :honeypot_url
  validate :honeypot_must_be_blank

  # ---- Validations ----
  validates :title,       presence: true, length: { maximum: 160 }
  validates :description, presence: true
  validates :category,    presence: true, inclusion: { in: CATEGORIES }
  validates :website,        allow_blank: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :contact_email,  allow_blank: true, format: URI::MailTo::EMAIL_REGEXP

  # ---- Défauts ----
  before_validation :apply_defaults

  private

  def apply_defaults
    self.source    ||= 'user'
    self.is_active = false if is_active.nil?
  end

  def geocode_if_needed
    return unless latitude.blank? || longitude.blank?
    q = [address, postcode, city].compact.join(', ').strip
    return if q.blank?

    if (res = Geocoder.search(q).first)
      self.latitude  ||= res.latitude
      self.longitude ||= res.longitude
      self.location  ||= res.city.presence || city
    end
  end

  def honeypot_must_be_blank
    errors.add(:base, 'Spam détecté') if honeypot_url.present?
  end
end






