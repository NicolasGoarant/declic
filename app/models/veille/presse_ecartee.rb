# frozen_string_literal: true

module Veille
  # URL d'un article de presse écarté dans /admin/veille/presse : rien d'autre n'est conservé.
  class PresseEcartee < ApplicationRecord
    self.table_name = "veille_presse_ecartees"

    validates :url, presence: true, uniqueness: true
  end
end
