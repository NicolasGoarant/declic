# frozen_string_literal: true

module Veille
  # Les 20 communes de la Métropole du Grand Nancy. Sert à écarter ce qui est
  # hors territoire, avant (champ de lieu structuré) et après (commune proposée
  # par l'enrichissement) l'appel à l'IA.
  module GrandNancy
    COMMUNES = [
      "Art-sur-Meurthe", "Dommartemont", "Essey-lès-Nancy", "Fléville-devant-Nancy",
      "Heillecourt", "Houdemont", "Jarville-la-Malgrange", "Laneuveville-devant-Nancy",
      "Laxou", "Ludres", "Malzéville", "Maxéville", "Nancy", "Pulnoy", "Saint-Max",
      "Saulxures-lès-Nancy", "Seichamps", "Tomblaine", "Vandœuvre-lès-Nancy",
      "Villers-lès-Nancy"
    ].freeze

    # Écritures courantes qui ne tombent pas sur le nom officiel.
    ALIAS = { "vandoeuvre" => "Vandœuvre-lès-Nancy", "villers" => "Villers-lès-Nancy",
              "essey" => "Essey-lès-Nancy", "jarville" => "Jarville-la-Malgrange",
              "laneuveville" => "Laneuveville-devant-Nancy", "saulxures" => "Saulxures-lès-Nancy",
              "fleville" => "Fléville-devant-Nancy", "art sur meurthe" => "Art-sur-Meurthe" }.freeze

    PAR_CLE = COMMUNES.index_by { |c| Text.normalize(c) }.merge(ALIAS.transform_keys { |k| Text.normalize(k) }).freeze

    module_function

    # Nom officiel si `nom` est une commune du Grand Nancy (casse, accents, tirets ignorés).
    def canonique(nom)
      cle = Text.normalize(nom).sub(/\A(ville de|commune de)\s+/, "")
      PAR_CLE[cle]
    end

    def inclut?(nom) = canonique(nom).present?

    # Première commune du Grand Nancy citée dans un texte libre, sinon nil.
    # Les noms les plus longs d'abord, pour que « Villers-lès-Nancy » ne
    # soit pas lu « Nancy ».
    def trouver_dans(texte)
      norme = " #{Text.normalize(texte)} "
      PAR_CLE.keys.sort_by { |k| -k.length }.each do |cle|
        return PAR_CLE[cle] if norme.include?(" #{cle} ")
      end
      nil
    end
  end
end
