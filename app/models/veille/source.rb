module Veille
  # Registre des publications surveillées. Aucun collecteur n'est branché
  # à ce stade : la table sert de référentiel et de rattachement pour les
  # candidats importés à la main via rake veille:import.
  class Source < ApplicationRecord
    KINDS = %w[presse magazine_municipal media_public].freeze

    enum :kind, KINDS.index_by(&:itself), validate: true

    has_many :candidates,
             class_name:  "Veille::Candidate",
             foreign_key: :veille_source_id,
             inverse_of:  :source,
             dependent:   :nullify

    validates :name, presence: true, uniqueness: true
    validates :url,  presence: true

    scope :actives, -> { where(active: true) }

    def to_s = name
  end
end
