# Les six catégories d'opportunités et les Belles Histoires : libellé, couleur et icône, écrits ici
# et nulle part ailleurs. Le front (diorama, volet, filtres) les reçoit en JSON.
#
# `cle` est la valeur stockée en base (Opportunity#category) ; « histoires » désigne les
# Belles Histoires (modèle Story), qui n'ont pas de colonne catégorie.
#
# Les couleurs sont celles relevées sur la maquette des pins (maquette-declic-v3 de
# nancy-3d, docs/maquettes/declic-maquette-pins-v1.png). Pratiquer et Découvrir : icônes Fluent Emoji 3D
# de Microsoft (licence MIT), 🛠️ et 🎭.
class Categorie
  Definition = Data.define(:cle, :libelle, :couleur, :icone)

  HISTOIRES = "histoires".freeze

  TOUTES = [
    Definition.new(cle: "ecologiser",   libelle: "Écologiser",       couleur: "#82C162", icone: "markers/ecologiser"),
    Definition.new(cle: "entreprendre", libelle: "Entreprendre",     couleur: "#F8910E", icone: "markers/entreprendre"),
    Definition.new(cle: "formation",    libelle: "Se former",        couleur: "#5A75E8", icone: "markers/formation"),
    Definition.new(cle: "benevolat",    libelle: "S'engager",        couleur: "#E85DAB", icone: "markers/benevolat"),
    Definition.new(cle: "pratiquer",    libelle: "Pratiquer",        couleur: "#EBBF60", icone: "markers/pratiquer"),
    Definition.new(cle: "decouvrir",    libelle: "Découvrir",        couleur: "#2AA7B8", icone: "markers/decouvrir"),
    Definition.new(cle: HISTOIRES,      libelle: "Belles Histoires", couleur: "#9472F6", icone: "markers/histoires")
  ].freeze

  PAR_CLE = TOUTES.index_by(&:cle).freeze

  def self.trouver(cle)
    PAR_CLE[cle.to_s.downcase]
  end
end
