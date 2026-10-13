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
    STATUSES   = %w[pending retenu ecarte publie].freeze

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

    validates :url, presence: true, uniqueness: true
    validates :score, numericality: {
      only_integer:             true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to:    100
    }, allow_nil: true

    # La file de tri : ce que l'admin doit trancher, le plus prometteur d'abord.
    scope :file_de_tri, -> { pending.order(Arel.sql("score DESC NULLS LAST"), created_at: :desc) }
    scope :qualifies,   -> { where.not(qualified_at: nil) }

    def qualified? = qualified_at.present?

    # Le tampon de travail est-il disponible ? Après publication il ne
    # l'est plus, par construction (voir Story#purge_veille_candidate_full_text).
    def full_text? = full_text.present?

    def source_label = source&.name.presence || host

    def host
      URI.parse(url.to_s).host&.delete_prefix("www.")
    rescue URI::InvalidURIError
      nil
    end
  end
end
