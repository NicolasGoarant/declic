# frozen_string_literal: true

require "roo"

module Veille
  # Importe le repérage initial (.xlsx) comme premiers éléments de la file de
  # relecture, au statut « à vérifier », sans appel IA.
  #
  # Onglets lus : « Opportunités » et « Belles Histoires - pistes » (comparaison
  # sans accents ni casse). Les colonnes sont reconnues par leur en-tête, avec des
  # variantes (titre/intitulé/nom, lien/url/source…) ; une ligne sans titre ou
  # sans lien est comptée comme ignorée, jamais devinée.
  class XlsxImporter
    ONGLETS = { "opportunites" => "opportunite", "belles histoires pistes" => "belle_histoire" }.freeze

    COLONNES = {
      title:   %w[titre intitule nom opportunite piste sujet],
      url:     %w[lien url lien source lien d origine source url],
      summary: %w[resume description descriptif detail details],
      commune: %w[commune ville lieu],
      category: %w[categorie],
      date:    %w[date dates quand echeance],
      origin_name: %w[source organisme structure porteur]
    }.freeze

    Bilan = Struct.new(:crees, :doublons, :ignores, :onglets, keyword_init: true)

    def initialize(chemin, today: Date.current, now: Time.current)
      @chemin = chemin
      @today  = today
      @now    = now
    end

    def call
      bilan = Bilan.new(crees: 0, doublons: 0, ignores: 0, onglets: [])
      classeur = Roo::Excelx.new(@chemin.to_s)

      classeur.sheets.each do |nom|
        type = ONGLETS[Text.normalize(nom)] or next
        bilan.onglets << nom
        importer_onglet(classeur.sheet(nom), type, bilan)
      end
      bilan
    end

    private

    def importer_onglet(feuille, type, bilan)
      lignes = feuille.to_a
      entetes_idx = lignes.index { |l| trouver_colonnes(l).key?(:title) } or return
      colonnes = trouver_colonnes(lignes[entetes_idx])

      lignes[(entetes_idx + 1)..].each do |ligne|
        valeurs = colonnes.transform_values { |i| ligne[i].to_s.strip.presence }
        if valeurs[:title].nil? || valeurs[:url].nil?
          bilan.ignores += 1
          next
        end

        if enregistrer(valeurs, type)
          bilan.crees += 1
        else
          bilan.doublons += 1
        end
      end
    end

    def trouver_colonnes(entetes)
      trouvees = {}
      Array(entetes).each_with_index do |e, i|
        norme = Text.normalize(e)
        COLONNES.each do |cle, variantes|
          trouvees[cle] ||= i if variantes.include?(norme) || (cle == :url && norme.include?("lien"))
        end
      end
      trouvees
    end

    def enregistrer(v, type)
      date = parse_date(v[:date])
      return false if Candidate.doublon?(url: v[:url], title: v[:title], starts_on: date, origin: "import_xlsx")

      Candidate.create!(
        origin: "import_xlsx", url: v[:url], title: v[:title].slice(0, 250), excerpt: v[:summary], summary: v[:summary],
        item_type: type, declic_category: categorie(v[:category]), commune: GrandNancy.canonique(v[:commune]) || v[:commune],
        starts_on: date, schedule_text: (date ? nil : v[:date]), reliability: "basse",
        status: "a_verifier", fetched_at: @now, reason: "Repérage initial : à vérifier"
      )
    end

    # « Se former », « S'engager »… ou la clé directe.
    def categorie(libelle)
      return nil if libelle.blank?

      norme = Text.normalize(libelle)
      Categorie::TOUTES.find { |c| c.cle != Categorie::HISTOIRES && [Text.normalize(c.libelle), c.cle].include?(norme) }&.cle
    end

    def parse_date(valeur)
      valeur.present? ? Date.parse(valeur.to_s) : nil
    rescue Date::Error
      nil
    end
  end
end
