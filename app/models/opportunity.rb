# app/models/opportunity.rb
class Opportunity < ApplicationRecord
  # --- Stockage JSON (SQLite/Postgres) ---
  attribute :raw_payload, :json

  # Pièce jointe principale (image de couverture)
  has_one_attached :image

  # Tu peux garder ça si tu veux d'autres photos plus tard
  has_many_attached :photos

  # --- Slug ---
  extend FriendlyId
  friendly_id :title, use: %i[slugged finders]

  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_title?
  end

  # --- Scopes / constantes ---
  CATEGORIES = %w[benevolat formation rencontres entreprendre ecologiser].freeze
  scope :active,      -> { where(is_active: true) }
  scope :with_coords, -> { where.not(latitude: nil, longitude: nil) }

  # --- Géocodage (location -> lat/lng) ---
  geocoded_by :location, latitude: :latitude, longitude: :longitude
  before_validation :geocode_if_needed,
                    if: -> { location.present? && (latitude.blank? || longitude.blank?) }

  # --- Anti-spam (honeypot) ---
  attr_accessor :honeypot_url
  validate :honeypot_must_be_blank

  # --- Validations ---
  validates :title,       presence: true, length: { maximum: 160 }
  validates :description, presence: true
  validates :category,    presence: true, inclusion: { in: CATEGORIES }

  validates :website,
           allow_blank: true,
           format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
           if: -> { self.class.column_names.include?("website") }

  validates :contact_email,
           allow_blank: true,
           format: URI::MailTo::EMAIL_REGEXP,
           if: -> { self.class.column_names.include?("contact_email") }

  validates :latitude,
           numericality: {
             greater_than_or_equal_to: -90,
             less_than_or_equal_to: 90
           },
           allow_nil: true

  validates :longitude,
           numericality: {
             greater_than_or_equal_to: -180,
             less_than_or_equal_to: 180
           },
           allow_nil: true

  # --- Défauts ---
  before_validation :apply_defaults

  # =========== Helpers « virage » CSV ===========
  def skills_list
    skills.to_s.split(/[;,]/).map(&:strip).reject(&:blank?)
  end

  def impact_domains_list
    impact_domains.to_s.split(/[;,]/).map(&:strip).reject(&:blank?)
  end

  # Score indicatif
  def relevance_score
    score = 0
    score += 3 if career_outcome.to_s =~ /(reconversion|emploi)/i
    score += 2 if credential.to_s     =~ /(certificat|rncp)/i
    score += 2 if schedule.to_s       =~ /(soir|week)/i
    score += 2 if mentorship || alumni_network
    score += 2 if format.to_s         =~ /(distanciel|hybride)/i
    score += 2 if selectivity_level.to_s =~ /(sélectif|entretien|dossier)/i
    score += 1 if respond_to?(:application_deadline) &&
                  application_deadline.present? &&
                  application_deadline <= 45.days.from_now
    score -= 3 if description.to_s.length < 140
    score
  end
  # ======================================

  # --- Choix intelligent d’image pour le front ---
  def hero_image_url(view_context)
    if image.attached?
      view_context.url_for(image)
    elsif image_url.present?
      # URL absolue ou asset interne
      (image_url =~ /\Ahttp/i) ? image_url : view_context.asset_path(image_url)
    else
      # Fallback très simple (ou laisse vide si tu n'as pas d'asset)
      view_context.asset_path("fallback-opportunity.jpg") rescue ""
    end
  end

  private

  def apply_defaults
    self.source    ||= "user" if respond_to?(:source)
    self.is_active = false if is_active.nil?
  end

  def geocode_if_needed
    geocode
  rescue => e
    Rails.logger.warn("[geocode_if_needed] #{e.class}: #{e.message}")
  end

  def honeypot_must_be_blank
    errors.add(:base, "Spam détecté") if honeypot_url.present?
  end
end
