# « Ce qu'il faut retenir » d'une Belle Histoire : au plus 3 objets {icone, titre, texte},
# stockés dans la colonne json stories.points_forts (clés en chaînes).
module PointsForts
  MAX = 3
  CLES = %w[icone titre texte].freeze
  VIDE = { "icone" => "", "titre" => "", "texte" => "" }.freeze

  # Courte liste d'icônes proposées dans l'admin : clé => [emoji, libellé].
  ICONES = {
    "coeur" => [ "❤️", "Cœur" ],
    "goutte" => [ "💧", "Goutte" ],
    "fiole" => [ "🧪", "Expertise" ],
    "groupe" => [ "👥", "Groupe" ],
    "maison" => [ "🏠", "Lieu" ],
    "feuille" => [ "🌱", "Nature" ],
    "livre" => [ "📖", "Savoir" ],
    "etoile" => [ "⭐", "Réussite" ]
  }.freeze

  # Ancien format highlights_items : une ligne = un point, puces « - », « • », « * » retirées.
  def self.depuis_lignes(texte)
    texte.to_s.lines
         .map { |ligne| ligne.strip.sub(/\A[-•*]\s*/, "").strip }
         .reject(&:empty?)
         .map { |ligne| VIDE.merge("texte" => ligne) }
  end

  # Liste propre pour l'affichage et l'enregistrement : clés attendues seulement, icône
  # limitée à la liste, points sans titre ni texte écartés (une icône seule ne fait pas un point).
  def self.normaliser(valeur)
    Array(valeur).filter_map do |point|
      point = point.to_unsafe_h if point.respond_to?(:to_unsafe_h)
      next unless point.respond_to?(:to_h)

      propre = CLES.index_with { |cle| point.to_h.stringify_keys[cle].to_s.strip }
      propre["icone"] = "" unless ICONES.key?(propre["icone"])
      propre if propre["titre"].present? || propre["texte"].present?
    end
  end
end
