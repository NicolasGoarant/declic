module Veille
  # Un article repéré, en attente de tri puis de réécriture.
  #
  # Cycle de vie :
  #   pending  → créé par rake veille:import, qualifié par Veille::Qualifier
  #   retenu   → validé à la main dans /admin/veille
  #   ecarte   → rejeté à la main
  #   publie   → une Story a été créée à partir de ce candidat
  class Candidate < ApplicationRecord
    CATEGORIES = %w[belle_histoire autre].freeze
    STATUSES   = %w[pending a_verifier retenu ecarte publie].freeze

    # Règle éditoriale : une opportunité invite à agir ; une belle histoire est un récit.
    ITEM_TYPES   = %w[opportunite belle_histoire].freeze
    RELIABILITY  = %w[haute moyenne basse].freeze
    DRAFT_STATUSES = %w[aucun redige a_reprendre a_verifier].freeze
    # Essais de rédaction automatique par candidat avant d'attendre la main d'un humain.
    MAX_REDACTIONS_AUTO = 3
    ORIGINS = {
      "jeveuxaider"     => "JeVeuxAider",
      "agenda_nancy"    => "Agenda Grand Nancy",
      "formation"       => "Formation Lorraine",
      "transentreprise" => "Transentreprise",
      "gazette"         => "La Gazette France",
      "presse"          => "Presse locale",
      "import_xlsx"     => "Repérage initial"
    }.freeze

    # category reste nil tant que la passe A n'a pas tourné : allow_nil.
    # status est renseigné dès la création (défaut "pending"), donc requis.
    enum :category, CATEGORIES.index_by(&:itself), validate: { allow_nil: true }
    enum :status,   STATUSES.index_by(&:itself),   validate: true

    belongs_to :source,
               class_name:  "Veille::Source",
               foreign_key: :veille_source_id,
               inverse_of:  :candidates,
               optional:    true

    has_one :story,
            class_name:  "::Story",
            foreign_key: :veille_candidate_id,
            inverse_of:  :veille_candidate,
            dependent:   :nullify

    belongs_to :opportunity, optional: true, inverse_of: :veille_candidate

    has_many :appels_ia,
             class_name:  "Veille::AppelIa",
             foreign_key: :candidate_id,
             inverse_of:  :candidate,
             dependent:   :nullify

    validates :url, presence: true, uniqueness: true
    validates :item_type,       inclusion: { in: ITEM_TYPES },  allow_nil: true
    validates :declic_category, inclusion: { in: ::Opportunity::CATEGORIES }, allow_nil: true
    validates :reliability,     inclusion: { in: RELIABILITY }, allow_nil: true
    validates :draft_status,    inclusion: { in: DRAFT_STATUSES }

    before_validation :set_normalized_title
    validates :score, numericality: {
      only_integer:             true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to:    100
    }, allow_nil: true

    # La file de tri : ce que l'admin doit trancher, le plus prometteur d'abord.
    scope :file_de_tri, -> { pending.order(Arel.sql("score DESC NULLS LAST"), created_at: :desc) }
    scope :qualifies,   -> { where.not(qualified_at: nil) }

    scope :par_type,      ->(t) { t.present? ? where(item_type: t) : all }
    scope :par_categorie, ->(c) { c.present? ? where(declic_category: c) : all }
    scope :par_origine,   ->(o) { o.present? ? where(origin: o) : all }
    scope :collectes_depuis, ->(d) { d.present? ? where("veille_candidates.fetched_at >= ? OR veille_candidates.created_at >= ?", d, d) : all }
    # Ce qui attend encore un enrichissement IA : jamais passé par AiEnricher, pas déjà tranché.
    scope :a_enrichir, -> { where(enriched_at: nil, status: %w[pending]).where(discard_reason: nil) }
    # Belles histoires enrichies dont le récit reste à rédiger : jamais tenté, ou tenté sur incident
    # d'API (« à reprendre »), moins de MAX_REDACTIONS_AUTO fois. Un brouillon refusé par les
    # contrôles (« à vérifier ») n'est pas relancé tout seul : il attend un humain.
    scope :a_rediger, lambda {
      where(item_type: "belle_histoire", status: %w[pending retenu], draft_status: %w[aucun a_reprendre], draft_body: [nil, ""])
        .where(discard_reason: nil).where.not(summary: [nil, ""]).where("draft_attempts < ?", MAX_REDACTIONS_AUTO)
    }
    # À relire par un humain : enrichi, non écarté. « À vérifier » en fait partie.
    scope :a_relire, -> { where(status: %w[pending a_verifier]).where(discard_reason: nil) }

    def self.origine_label(origine) = ORIGINS.fetch(origine.to_s, origine.to_s.humanize)

    # Dédoublonnage : même URL, ou même titre normalisé avec la même date de début.
    # Sans date (régime « toute l'année »), la même origine est exigée en plus, pour ne pas
    # confondre deux missions homonymes de sources différentes.
    def self.doublon?(url:, title:, starts_on: nil, origin: nil)
      return true if url.present? && exists?(url: url)

      norme = Veille::Text.normalize(title)
      return false if norme.blank?

      scope = where(normalized_title: norme, starts_on: starts_on)
      scope = scope.where(origin: origin) if starts_on.nil?
      scope.exists?
    end

    def qualified? = qualified_at.present?
    def opportunite?    = item_type == "opportunite"
    def histoire?       = item_type == "belle_histoire"
    def enriched?       = enriched_at.present?
    def categorie_label = declic_category && Categorie.trouver(declic_category)&.libelle
    def origine_label   = self.class.origine_label(origin)

    # Date ou régime tel qu'affiché dans la file.
    def quand
      return schedule_text if starts_on.nil? && ends_on.nil?
      return I18n.l(starts_on, format: "%-d/%m/%Y") if ends_on.nil? || ends_on == starts_on
      "#{starts_on && I18n.l(starts_on, format: '%-d/%m/%Y')} → #{I18n.l(ends_on, format: '%-d/%m/%Y')}"
    end

    # Le tampon de travail est-il disponible ? Après publication il ne
    # l'est plus, par construction (voir Story#purge_veille_candidate_full_text).
    def full_text? = full_text.present?

    def source_label = source&.name.presence || (origin.present? ? origine_label : host)

    def host
      URI.parse(url.to_s).host&.delete_prefix("www.")
    rescue URI::InvalidURIError
      nil
    end

    private

    def set_normalized_title
      self.normalized_title = Veille::Text.normalize(title).presence
    end
  end
end
