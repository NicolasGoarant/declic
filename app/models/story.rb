class Story < ApplicationRecord
  # Candidat de veille dont cette fiche est issue. Nil pour les histoires
  # saisies à la main ou proposées par le public.
  belongs_to :veille_candidate,
             class_name: "Veille::Candidate",
             inverse_of: :story,
             optional:   true

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

  # Le texte intégral de l'article source est un tampon de travail, et rien
  # de plus : dès que la fiche est créée, il est effacé.
  #
  # Déclic évite de constituer une base dérivée d'articles de presse. On
  # conserve la fiche réécrite et le lien vers la source d'origine ; on ne
  # conserve pas l'article. Ne jamais transformer ce callback en archivage.
  after_create :purge_veille_candidate_full_text

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

  def purge_veille_candidate_full_text
    return if veille_candidate.nil? || veille_candidate.full_text.blank?

    # update_columns : on est dans un after_create, on ne veut ni relancer
    # les validations du candidat ni déclencher d'autres callbacks.
    veille_candidate.update_columns(full_text: nil, updated_at: Time.current)
    Rails.logger.info(
      "[Veille] full_text purgé du candidat ##{veille_candidate.id} après création de la Story ##{id}"
    )
  end

  def ensure_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end

  def set_default_active
    self.is_active = false if is_active.nil?
  end
end
