# frozen_string_literal: true

module Veille
  # Une ligne du journal par appel à l'API Anthropic. Écrite par AiPass#run, jamais
  # à la main : c'est la trace qui fonde le plafond mensuel et l'état de dépense.
  class AppelIa < ApplicationRecord
    self.table_name = "veille_appels_ia"

    PASSES  = %w[enrichissement redaction].freeze
    STATUTS = %w[ok erreur_api illisible refuse_controle plafond].freeze

    belongs_to :candidate, class_name: "Veille::Candidate", optional: true, inverse_of: :appels_ia

    validates :passe,  inclusion: { in: PASSES }
    validates :statut, inclusion: { in: STATUTS }
    validates :modele, presence: true

    scope :du_mois, ->(jour = Date.current) { where(created_at: jour.beginning_of_month.beginning_of_day..jour.end_of_month.end_of_day) }

    def self.cout_du_mois(jour = Date.current) = du_mois(jour).sum(:cout_usd).to_f
  end
end
