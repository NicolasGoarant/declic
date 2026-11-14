# frozen_string_literal: true

require "json"

module Veille
  # Transfert des candidats triés d'une base à l'autre (local → production) sans refaire payer l'IA.
  # Le fichier JSON ne contient ni full_text, ni corps rédigé, ni fiche : seulement le résultat du tri.
  # L'import ne touche jamais un candidat déjà présent, ne crée aucune fiche et ne publie rien.
  module Transfert
    VERSION = 1

    # Colonnes reprises. Pas de full_text, draft_body, opportunity_id, veille_source_id (propres à chaque base).
    CHAMPS = %w[
      url origin title excerpt published_on status item_type declic_category score reason reliability discard_reason
      classement_manuel commune starts_on ends_on start_time end_time schedule_text summary famille role_public zone
      adresse normalized_title fetched_at enriched_at
    ].freeze

    # Statuts importables. « publie » est refusé : il suppose une fiche qui n'existe pas dans la base cible.
    STATUTS_IMPORTABLES = (Candidate::STATUSES - %w[publie]).freeze

    PREMIER_AVIS = /premier score (\d+)(?:, premier verdict ([^)]+))?\)/

    module_function

    # ---- Export -------------------------------------------------------------------------------------------------
    def exporter(scope = Candidate.all)
      candidats = scope.includes(:source, :appels_ia).order(:id).map { |c| ligne(c) }
      { "version" => VERSION, "exporte_le" => Time.current.iso8601, "nombre" => candidats.size, "candidats" => candidats }
    end

    def ligne(c)
      h = CHAMPS.to_h { |k| [k, valeur(c.public_send(k))] }
      h["source"] = c.source&.name
      premier = c.reason.to_s.match(PREMIER_AVIS)
      h["avis_haiku"] = premier && { "score" => premier[1].to_i, "verdict" => premier[2] }.compact
      h["appels_ia"] = c.appels_ia.map { |a| { "passe" => a.passe, "modele" => a.modele, "statut" => a.statut } }
      h
    end

    def valeur(v)
      case v
      when Time, ActiveSupport::TimeWithZone then v.respond_to?(:year) && v.year == 2000 && v.month == 1 ? v.strftime("%H:%M") : v.utc.iso8601
      when Date then v.iso8601
      else v
      end
    end

    # ---- Import -------------------------------------------------------------------------------------------------
    Rapport = Struct.new(:crees, :ignores, :refuses, :detail_refus, :detail_ignores, keyword_init: true) do
      def self.vide = new(crees: 0, ignores: 0, refuses: 0, detail_refus: [], detail_ignores: Hash.new(0))
    end

    def importer(donnees, dry_run: false)
      rapport = Rapport.vide
      vus = Set.new
      Array(donnees["candidats"]).each do |h|
        url = h["url"].to_s.strip
        refus = motif_refus(h, url)
        if refus
          rapport.refuses += 1
          rapport.detail_refus << "#{url.presence || '(sans URL)'} : #{refus}"
          next
        end
        if Candidate.exists?(url: url) || !vus.add?(url)
          rapport.ignores += 1
          rapport.detail_ignores["déjà présent (URL)"] += 1
          next
        end
        if Candidate.doublon?(url: url, title: h["title"], starts_on: lire_date(h["starts_on"]), origin: h["origin"])
          rapport.ignores += 1
          rapport.detail_ignores["déjà présent (même titre et même date)"] += 1
          next
        end
        creer(h, url) unless dry_run
        rapport.crees += 1
      end
      rapport
    end

    def motif_refus(h, url)
      return "URL absente" if url.blank?
      return "statut « #{h['status']} » non importable (aucune fiche n'est importée)" unless STATUTS_IMPORTABLES.include?(h["status"])
      return "type inconnu « #{h['item_type']} »" if h["item_type"].present? && !Candidate::ITEM_TYPES.include?(h["item_type"])
      return "catégorie inconnue « #{h['declic_category']} »" if h["declic_category"].present? && !::Opportunity::CATEGORIES.include?(h["declic_category"])
      return "score hors 0–100" if h["score"].present? && !h["score"].to_i.between?(0, 100)
      nil
    end

    def creer(h, url)
      attrs = h.slice(*CHAMPS).except("url")
      %w[published_on starts_on ends_on].each { |k| attrs[k] = lire_date(attrs[k]) }
      %w[fetched_at enriched_at].each { |k| attrs[k] = attrs[k].present? ? Time.zone.parse(attrs[k]) : nil }
      attrs["classement_manuel"] = attrs["classement_manuel"] == true
      attrs["draft_status"] = "aucun"
      Candidate.create!(attrs.merge("url" => url))
    end

    def lire_date(v) = v.present? ? Date.iso8601(v.to_s) : nil
  end
end
