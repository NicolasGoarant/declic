# frozen_string_literal: true

module Veille
  # Un élément brut tel que le rapporte un connecteur, avant stockage.
  # Les champs *_hint sont des indices tirés de la source (catégorie d'agenda,
  # lieu structuré…) : l'enrichissement tranche, eux ne font que l'aider.
  Item = Struct.new(
    :origin, :url, :title, :text, :published_on, :starts_on, :ends_on,
    :schedule_text, :commune, :category_hint, :type_hint, :reliability,
    keyword_init: true
  ) do
    def to_candidate_attributes(source: nil, now: Time.current)
      {
        origin: origin, url: url, title: title.to_s.squish.slice(0, 250), full_text: text,
        excerpt: text.to_s.squish.slice(0, 400), published_on: published_on,
        starts_on: starts_on, ends_on: ends_on, schedule_text: schedule_text,
        commune: commune, declic_category: category_hint, item_type: type_hint,
        reliability: reliability, fetched_at: now, source: source
      }
    end
  end
end
