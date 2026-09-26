# app/models/opportunity.rb
class Opportunity < ApplicationRecord
  include NancyGeocodable

  # --- Stockage JSON (SQLite/Postgres) ---
  attribute :raw_payload, :json

  # --- Images ---
  # Image principale (bandeau hero)
  has_one_attached :image

  # Photos inline dans le texte (système <!-- IMAGE_1 -->, <!-- IMAGE_2 -->, <!-- IMAGE_3 -->)
  # Identique au système des stories pour un style éditorial magazine
  has_one_attached :inline_image_1
  has_one_attached :inline_image_2
  has_one_attached :inline_image_3

  # Galerie photos : ordre, couverture, suppressions (voir GaleriePhotos)
  include GaleriePhotos
  include FicheCompletude

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

  # --- Géocodage (location -> lat/lng), restreint à la zone de Nancy ---
  # `nancy_geocoded_by` (NancyGeocodable) ajoute une boîte de recherche à la
  # requête Nominatim ET un garde-fou de distance après coup : voir le
  # commentaire du concern pour le cas qui a rendu ça nécessaire.
  nancy_geocoded_by :location, latitude: :latitude, longitude: :longitude
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

  # --- Defaults ---
  before_validation :apply_defaults

  # --- Dates saisies (start_date / end_date) ---
  # Ce sont des chaînes : le formulaire admin écrit de l'ISO (AAAA-MM-JJ, <input type=date>),
  # mais l'historique contient du texte libre (« Toute l'année », « Inscriptions jusqu'au … »).
  # Seul l'ISO strict compte comme une date ; tout le reste vaut « sans date ».
  # Les colonnes de référence sont désormais starts_on / ends_on (+ start_time / end_time) ;
  # la reprise de l'historique est décrite dans ConversionDates.
  def self.date_iso(valeur) = ConversionDates.date_iso(valeur)

  def date_debut = starts_on || self.class.date_iso(start_date)
  def date_fin   = ends_on || self.class.date_iso(end_date)

  # Pont temporaire dans les deux sens, tant que des vues de production lisent encore les chaînes :
  #   - starts_on / ends_on modifiés (formulaire admin) -> start_date / end_date en AAAA-MM-JJ ;
  #   - sinon start_date / end_date modifiés (anciens écrans, import) -> starts_on / ends_on.
  # Les colonnes dates l'emportent si les deux changent. Un texte libre dans start_date n'est
  # jamais écrasé tant que starts_on ne change pas.
  before_save :synchroniser_dates

  # --- Affichage des dates (fiche Opportunité) ---
  JOURS_ABREGES = %w[dim. lun. mar. mer. jeu. ven. sam.].freeze
  MOIS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  # Sans aucune date : « Ouvert toute l'année », etc. (le détail va dans schedule_text).
  def permanente? = starts_on.nil? && ends_on.nil?

  # Pas encore terminée (inclut une opportunité en cours) ; faux si permanente.
  def a_venir? = !permanente? && derniere_date >= aujourdhui_a_paris
  def passee?  = !permanente? && derniere_date < aujourdhui_a_paris

  # « Sam. 14 février 2026 », « Du sam. 14 février au dim. 15 mars 2026 », « Jusqu'au … » ; nil si permanente.
  def date_affichee
    return nil if permanente?
    return "Jusqu'au #{jour_en_toutes_lettres(ends_on)}" if starts_on.nil?
    return jour_en_toutes_lettres(starts_on).upcase_first if ends_on.nil? || ends_on == starts_on

    debut = jour_en_toutes_lettres(starts_on, annee: starts_on.year != ends_on.year)
    "Du #{debut} au #{jour_en_toutes_lettres(ends_on)}"
  end

  # « 14h - 18h », « 9h30 », sinon schedule_text (« Ouvert toute l'année, sur rendez-vous »).
  def horaire_affiche
    heures = [ start_time, end_time ].compact.map { |t| t.min.zero? ? "#{t.hour}h" : "%dh%02d" % [ t.hour, t.min ] }
    heures.any? ? heures.join(" - ") : schedule_text.presence
  end

  # --- Contenu de la fiche ---
  has_one_attached :organization_logo

  # « Au programme » : liste de chaînes (colonne json).
  def programme_liste = Array(programme).map { |etape| etape.to_s.strip }.reject(&:empty?)

  # Saisie admin : un textarea, une étape par ligne <-> tableau json.
  def programme_texte = programme_liste.join("\n")

  def programme_texte=(texte)
    self.programme = texte.to_s.lines.map(&:strip).reject(&:empty?)
  end

  # Champs que la nouvelle fiche affiche (voir FicheCompletude).
  def criteres_fiche
    {
      "photo" => a_une_photo?,
      "dates ou horaires" => starts_on.present? || schedule_text.present?,
      "adresse" => address.present? || location.present?,
      "résumé" => description.present?,
      "programme" => programme_liste.any?,
      "public" => audience.present?,
      "bouton" => cta_button_text.present? && cta_button_url.present?
    }
  end

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

  # --- Choix intelligent d'image pour le front ---
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
    geocode_and_guard
  rescue => e
    Rails.logger.warn("[geocode_if_needed] #{e.class}: #{e.message}")
  end

  def synchroniser_dates
    { start_date: :starts_on, end_date: :ends_on }.each do |chaine, date|
      if will_save_change_to_attribute?(date)
        self[chaine] = self[date]&.iso8601
      elsif will_save_change_to_attribute?(chaine)
        texte = self[chaine].to_s.strip
        if texte.empty?
          self[date] = nil
        elsif (iso = self.class.date_iso(texte))
          self[date] = iso
        end
      end
    end
  end

  def derniere_date = ends_on || starts_on
  def aujourdhui_a_paris = Time.current.in_time_zone(ConversionDates::FUSEAU).to_date

  def jour_en_toutes_lettres(date, annee: true)
    [ JOURS_ABREGES[date.wday], date.day, MOIS[date.month - 1], (date.year if annee) ].compact.join(" ")
  end

  def honeypot_must_be_blank
    errors.add(:base, "Spam détecté") if honeypot_url.present?
  end

  # before_validation :build_location

  # def build_location
  #  if address.present? && city.present? && postal_code.present?
  #    self.location = "#{address}, #{postal_code} #{city}, France"
  #  end
  # end
end
