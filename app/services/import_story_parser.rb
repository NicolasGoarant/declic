# frozen_string_literal: true

require "yaml"
require "date"

class ImportStoryParser
  class ParseError < StandardError; end

  FRONTMATTER_RE = /\A---\s*\n(.*?)\n---\s*\n/m.freeze

  def self.call(blob)
    blob = blob.to_s.strip
    raise ParseError, "Bloc vide" if blob.blank?

    match = blob.match(FRONTMATTER_RE)
    raise ParseError, "Frontmatter introuvable (--- ... ---)" unless match

    yaml_part = match[1]
    body = blob.sub(FRONTMATTER_RE, "").strip

    data = YAML.safe_load(
      yaml_part,
      permitted_classes: [Date],
      aliases: false
    ) || {}

    [normalize(data), clean_body(body)]
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

    out[:title]       = h["title"]       if h["title"].present?
    out[:chapo]       = h["chapo"]       if h["chapo"].present?
    out[:description] = h["description"] if h["description"].present?

    # ✅ FIX IMPORTANT : date peut être String OU Date (YAML auto-caste)
    if h["date"].is_a?(Date)
      out[:happened_on] = h["date"]
    elsif h["date"].present?
      out[:happened_on] = Date.parse(h["date"].to_s)
    end

    out[:location]  = h["location"] if h["location"].present?
    out[:latitude]  = h["lat"] if h["lat"].present?
    out[:longitude] = h["lng"] if h["lng"].present?

    if h["tags"].is_a?(Array)
      out[:tags] = h["tags"].join(", ")
    elsif h["tags"].is_a?(String)
      out[:tags] = h["tags"]
    end

    out[:source_name] = h["source_name"] if h["source_name"].present?
    out[:source_url]  = h["source_url"]  if h["source_url"].present?
    out[:image_url]   = h["image_hero"]  if h["image_hero"].present?

    out[:highlights_title] = h["highlights_title"] if h["highlights_title"].present?
    out[:highlights_text]  = h["highlights_text"]  if h["highlights_text"].present?

    if h["highlights_items"].is_a?(Array)
      out[:highlights_items] = h["highlights_items"].join("\n")
    end

    out
  rescue ArgumentError => e
    raise ParseError, e.message
  end
end
