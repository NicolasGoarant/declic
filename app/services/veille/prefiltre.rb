# frozen_string_literal: true

module Veille
  # Préfiltre de la presse, en code, avant tout appel IA : un élément n'est confié au modèle que s'il
  # évoque le territoire (communes du Grand Nancy, Meurthe-et-Moselle, Lorraine) ET un thème Déclic, et
  # s'il ne relève pas d'une exclusion (sport, faits divers, météo, politique nationale, horoscope).
  # Les listes de mots vivent dans config/veille/prefiltre.yml.
  module Prefiltre
    FICHIER = Rails.root.join("config/veille/prefiltre.yml")

    Verdict = Struct.new(:retenu, :motif, keyword_init: true) do
      alias_method :retenu?, :retenu
    end

    # Bilan d'un passage : éléments reçus, retenus, écartés (par motif).
    Bilan = Struct.new(:recus, :retenus, :ecartes, :motifs, keyword_init: true) do
      def self.vide = new(recus: 0, retenus: [], ecartes: 0, motifs: Hash.new(0))
    end

    Regles = Struct.new(:exclusions, :territoire, :themes, keyword_init: true)

    module_function

    def regles(fichier: FICHIER)
      @cache ||= {}
      @cache[[fichier.to_s, File.mtime(fichier)]] ||= begin
        brut = YAML.safe_load_file(fichier, symbolize_names: true)
        Regles.new(exclusions: compiler(brut.fetch(:exclusions)), territoire: compiler(territoire: brut.fetch(:territoire))[:territoire],
                   themes: compiler(brut.fetch(:themes)))
      end
    end

    # Titre + extrait du flux : les seules données lues pour la presse.
    def evaluer(titre:, texte: nil, regles: self.regles)
      norme = " #{Text.normalize([titre, texte].compact.join(' '))} "

      regles.exclusions.each do |groupe, motif|
        return Verdict.new(retenu: false, motif: "exclusion : #{groupe}") if norme.match?(motif)
      end
      return Verdict.new(retenu: false, motif: "hors territoire") unless Veille::GrandNancy.trouver_dans(norme) || norme.match?(regles.territoire)
      return Verdict.new(retenu: false, motif: "hors thèmes Déclic") unless regles.themes.values.any? { |motif| norme.match?(motif) }

      Verdict.new(retenu: true, motif: nil)
    end

    def evaluer_item(item, regles: self.regles) = evaluer(titre: item.title, texte: item.text, regles: regles)

    # Sépare les items retenus des écartés.
    def filtrer(items, regles: self.regles)
      Array(items).each_with_object(Bilan.vide) do |item, bilan|
        bilan.recus += 1
        verdict = evaluer_item(item, regles: regles)
        if verdict.retenu?
          bilan.retenus << item
        else
          bilan.ecartes += 1
          bilan.motifs[verdict.motif] += 1
        end
      end
    end

    # Un groupe de mots → une expression régulière sur texte normalisé (mots entiers).
    def compiler(groupes)
      groupes.transform_values do |mots|
        formes = Array(mots).map { |m| Text.normalize(m) }.reject(&:empty?).uniq.sort_by { |m| -m.length }
        formes.empty? ? /(?!)/ : /(?<=\s)(?:#{formes.map { |m| Regexp.escape(m) }.join('|')})(?=\s)/
      end
    end
  end
end
