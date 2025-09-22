# frozen_string_literal: true
module Ingest
  class Upserter
    def self.call(item)
      a = item.symbolize_keys

      # Fallbacks pour satisfaire les validations
      a[:summary]     = a[:summary].presence || a[:description].to_s.strip
      a[:description] = a[:description].presence || a[:summary].presence || a[:title].to_s

      # Dédup : URL prioritaire, sinon (date + titre)
      key_date = a[:starts_at]&.to_date
      scope = Opportunity.all

      existing =
        if a[:url].present?
          scope.where("lower(url) = lower(?)", a[:url]).first
        elsif key_date && a[:title].present?
          scope.where("date(starts_at) BETWEEN ? AND ?", key_date - 1, key_date + 1)
               .where("lower(title) = lower(?)", a[:title]).first
        end

      rec = existing || Opportunity.new

      # FriendlyId : régénère le slug si le titre change
      prev_title = rec.respond_to?(:title) ? rec.title : nil

      # N'assigne jamais :status (colonne absente)
      rec.assign_attributes(a.except(:score, :status))

      if defined?(FriendlyId) && rec.respond_to?(:slug=) && prev_title.present? && rec.title != prev_title
        rec.slug = nil
      end

      # Active par défaut ce qui est ingéré
      rec.is_active = true if rec.is_active.nil?

      rec.save!
      rec
    end
  end
end
