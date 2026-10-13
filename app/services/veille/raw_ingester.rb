# frozen_string_literal: true

module Veille
  # Stocke chaque élément brut collecté : source, URL, date de collecte, texte
  # récupéré. Dédoublonne (même URL, ou même titre normalisé à la même date),
  # écarte d'emblée ce qui est hors Grand Nancy ou déjà passé. Ne fait aucun
  # appel IA.
  #
  # Le texte brut va dans full_text, le tampon de travail que Veille::Story
  # efface à la création de la fiche (voir docs/veille.md) ; pour la presse, il
  # ne contient que le chapeau du flux, jamais l'article.
  class RawIngester
    Bilan = Struct.new(:crees, :doublons, :hors_zone, :passes, :invalides, keyword_init: true) do
      def self.vide = new(crees: [], doublons: 0, hors_zone: 0, passes: 0, invalides: 0)
    end

    def initialize(today: Date.current, now: Time.current)
      @today = today
      @now   = now
    end

    def ingest(items)
      bilan = Bilan.vide
      Array(items).each { |item| ingest_one(item, bilan) }
      bilan
    end

    private

    def ingest_one(item, bilan)
      if item.commune.present? && !Veille::GrandNancy.inclut?(item.commune)
        bilan.hors_zone += 1
      elsif (item.ends_on || item.starts_on)&.<(@today)
        bilan.passes += 1
      elsif Veille::Candidate.doublon?(url: item.url, title: item.title, starts_on: item.starts_on, origin: item.origin)
        bilan.doublons += 1
      else
        candidat = Veille::Candidate.new(item.to_candidate_attributes(now: @now))
        candidat.commune = Veille::GrandNancy.canonique(item.commune) || item.commune
        if candidat.save
          bilan.crees << candidat
        else
          bilan.invalides += 1
          Rails.logger.warn("[Veille] ingestion refusée #{item.url} : #{candidat.errors.full_messages.to_sentence}")
        end
      end
    end
  end
end
