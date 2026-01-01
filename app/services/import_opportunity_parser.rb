# frozen_string_literal: true

require "yaml"
require "date"
require "time"

class ImportOpportunityParser
  class ParseError < StandardError; end

  FRONTMATTER_RE = /\A---\s*\n(.*?)\n---\s*\n/m.freeze

  def self.call(blob)
    blob = blob.to_s.strip
    raise ParseError, "Bloc vide" if blob.blank?

    match = blob.match(FRONTMATTER_RE)
    raise ParseError, "Frontmatter introuvable (--- ... ---)" unless match

    yaml_part = match[1]
    body_raw  = blob.sub(FRONTMATTER_RE, "")
    body      = clean_body(body_raw)

    data = YAML.safe_load(
      yaml_part,
      permitted_classes: [Date, Time],
      aliases: false
    ) || {}

    [normalize(data), body]
  rescue Psych::Exception
    raise ParseError, "YAML invalide"
  end

  def self.clean_body(text)
    text.to_s
        .gsub(/:contentReference\[.*?\]\{.*?\}/, "")
        .gsub(/\n{3,}/, "\n\n")
        .strip
  end

  def self.normalize(data)
    h = data.transform_keys(&:to_s)
    out = {}

    out[:title]        = h["title"]        if h["title"].present?
    out[:category]     = h["category"]     if h["category"].present?
    out[:organization] = h["organization"] if h["organization"].present?

    # Active/visible
    if h.key?("is_active")
      out[:is_active] = !!h["is_active"]
    end

    # Localisation
    out[:location]  = h["location"] if h["location"].present?
    out[:latitude]  = h["lat"] || h["latitude"] if (h["lat"].present? || h["latitude"].present?)
    out[:longitude] = h["lng"] || h["longitude"] if (h["lng"].present? || h["longitude"].present?)

    # Temps / dates
    out[:time_commitment] = h["time_commitment"] if h["time_commitment"].present?
    out[:starts_at] = parse_timeish(h["starts_at"]) if h["starts_at"].present?
    out[:ends_at]   = parse_timeish(h["ends_at"])   if h["ends_at"].present?

    # Images (URLs)
    out[:image_url] = h["image_hero"] if h["image_hero"].present?
    out[:gallery_image_1] = h["gallery_1"] if h["gallery_1"].present?
    out[:gallery_image_2] = h["gallery_2"] if h["gallery_2"].present?
    out[:gallery_image_3] = h["gallery_3"] if h["gallery_3"].present?

    # Liens & contact
    out[:website]       = h["website"] if h["website"].present?
    out[:source_url]    = h["source_url"] if h["source_url"].present?
    out[:contact_email] = h["contact_email"] if h["contact_email"].present?
    out[:contact_phone] = h["contact_phone"] if h["contact_phone"].present?

    # Métadonnées
    if h["tags"].is_a?(Array)
      out[:tags] = h["tags"].join(", ")
    elsif h["tags"].is_a?(String)
      out[:tags] = h["tags"]
    end

    # Show enrichie
    out[:quote]        = h["quote"] if h["quote"].present?
    out[:quote_author] = h["quote_author"] if h["quote_author"].present?

    out[:stat_1_number] = h["stat_1_number"] if h["stat_1_number"].present?
    out[:stat_1_label]  = h["stat_1_label"]  if h["stat_1_label"].present?
    out[:stat_2_number] = h["stat_2_number"] if h["stat_2_number"].present?
    out[:stat_2_label]  = h["stat_2_label"]  if h["stat_2_label"].present?
    out[:stat_3_number] = h["stat_3_number"] if h["stat_3_number"].present?
    out[:stat_3_label]  = h["stat_3_label"]  if h["stat_3_label"].present?
    out[:stat_4_number] = h["stat_4_number"] if h["stat_4_number"].present?
    out[:stat_4_label]  = h["stat_4_label"]  if h["stat_4_label"].present?

    if h["challenges"].is_a?(Array)
      out[:challenges] = h["challenges"].join("\n")
    elsif h["challenges"].is_a?(String)
      out[:challenges] = h["challenges"]
    end

    out
  rescue ArgumentError => e
    raise ParseError, e.message
  end

  def self.parse_timeish(value)
    return value if value.is_a?(Time)
    return value.to_time if value.respond_to?(:to_time)
    Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
