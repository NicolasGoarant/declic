# frozen_string_literal: true

module Veille
  # Le jeu figé des 30 cas à étiqueter pour calibrer le prompt v4 (choisis le 31/10/2026 : douteux, à relire et contrôles, pas un tirage au hasard).
  # Il vit dans un fichier et non dans veille_candidates : plusieurs de ces candidats n'existent
  # plus en base. Pour la presse, seuls le titre et le lien sont repris, jamais le chapeau.
  module Etiquetage
    FICHIER = Rails.root.join("config/veille/etiquetage_2026-10-31.json")

    Cas = Struct.new(:ref, :titre, :source, :commune, :quand, :texte, :lien, :presse, :v4, :groupe, keyword_init: true)
    Comparaison = Struct.new(:lignes, :etiquetes, :reste, :accords, :comparables, keyword_init: true)

    def self.cas
      @cas ||= JSON.parse(FICHIER.read).map { |h| Cas.new(**h.symbolize_keys).freeze }.freeze
    end

    def self.trouver(ref) = cas.find { |c| c.ref == ref.to_s }

    # Rapproche chaque réponse de la décision de la v4. « Douteux » n'entre pas dans l'accord.
    def self.comparaison
      reponses = Etiquette.all.index_by(&:ref)
      lignes = cas.map { |c| { cas: c, etiquette: reponses[c.ref], accord: accord?(c, reponses[c.ref]) } }
      avis = lignes.count { |l| l[:etiquette]&.avis }
      Comparaison.new(lignes: lignes, etiquetes: avis, reste: cas.size - avis,
                      accords: lignes.count { |l| l[:accord] == true }, comparables: lignes.count { |l| !l[:accord].nil? })
    end

    def self.accord?(cas, etiquette)
      case etiquette&.avis
      when "garder"  then cas.v4["decision"] == "Gardé"
      when "ecarter" then cas.v4["decision"] == "Écarté"
      end
    end
    private_class_method :accord?
  end
end
