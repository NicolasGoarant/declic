module Veille
  # L'avis de l'éditeur sur un cas du jeu d'étiquetage (Veille::Etiquetage). Sert à calibrer
  # le prompt : ne touche ni aux candidats, ni à la file de relecture, ni aux fiches.
  class Etiquette < ApplicationRecord
    AVIS = { "garder" => "Garder", "ecarter" => "Écarter", "douteux" => "Douteux" }.freeze

    validates :ref, presence: true, uniqueness: true
    validates :avis, inclusion: { in: AVIS.keys }, allow_nil: true
  end
end
