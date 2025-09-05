# app/models/opportunity.rb
class Opportunity < ApplicationRecord
  # --- Stockage JSON (SQLite/Postgres) ---
  serialize :raw_payload, coder: JSON

  # --- Slug ---
  extend FriendlyId
  friendly_id :title, use: %i[slugged finders]
  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_title?
  end

  # --- Scopes / constantes ---
  scope :active, -> { where(is_active: true) }
  CATEGORIES = %w[benevolat formation rencontres entreprendre].freeze

  # --- Géocodage (adresse -> lat/lng) ---
  reverse_geocoded_by :latitude, :longitude
  before_validation :geocode_if_needed

  # --- Anti-spam (honeypot) ---
  attr_accessor :honeypot_url
  validate :honeypot_must_be_blank

  # --- Validations ---
  validates :title,       presence: true, length: { maximum: 160 }
  validates :description, presence: true
  validates :category,    presence: true, inclusion: { in: CATEGORIES }
  validates :website,        allow_blank: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :contact_email,  allow_blank: true, format: URI::MailTo::EMAIL_REGEXP

  # --- Défauts ---
  before_validation :apply_defaults

  # =========== Ajouts “virage” ===========
  # Helpers CSV -> Array
  def skills_list
    skills.to_s.split(/[;,]/).map(&:strip).reject(&:blank?)
  end

  def impact_domains_list
    impact_domains.to_s.split(/[;,]/).map(&:strip).reject(&:blank?)
  end

  # Score simple pour classer les offres qui “parlent” aux publics en reconversion/cadres
  def relevance_score
    score = 0
    score += 3 if career_outcome.to_s =~ /(reconversion|emploi)/i
    score += 2 if credential.to_s =~ /(certificat|rncp)/i
    score += 2 if schedule.to_s =~ /(soir|week)/i
    score += 2 if mentorship || alumni_network
    score += 2 if format.to_s =~ /(distanciel|hybride)/i
    score += 2 if selectivity_level.to_s =~ /(sélectif|entretien|dossier)/i
    score += 1 if application_deadline.present? && application_deadline <= 45.days.from_now
    score -= 3 if description.to_s.length < 140
    score
  end
  # ======================================

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







