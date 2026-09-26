# « Ce qu'il faut retenir » d'une Belle Histoire : au plus 3 objets {icone, titre, texte},
# stockés dans la colonne json stories.points_forts (clés en chaînes).
module PointsForts
  MAX = 3
  CLES = %w[icone titre texte].freeze

  # Ancien format highlights_items : une ligne = un point, puces « - », « • », « * » retirées.
  def self.depuis_lignes(texte)
    texte.to_s.lines
         .map { |ligne| ligne.strip.sub(/\A[-•*]\s*/, "").strip }
         .reject(&:empty?)
         .map { |ligne| { "icone" => "", "titre" => "", "texte" => ligne } }
  end

  # Liste propre pour l'affichage : clés attendues seulement, points vides écartés.
  def self.normaliser(valeur)
    Array(valeur).filter_map do |point|
      next unless point.respond_to?(:to_h)

      propre = CLES.index_with { |cle| point.to_h.stringify_keys[cle].to_s.strip }
      propre if propre["titre"].present? || propre["texte"].present?
    end
  end
end
