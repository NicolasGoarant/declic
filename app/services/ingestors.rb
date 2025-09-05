class Ingestors
  def self.run_all!
    Source.where(enabled: true).find_each do |src|
      run_source!(src)
    end
  end

  def self.run_source!(source)
    items =
      case source.kind
      when 'rss' then RssFetcher.new.fetch(source.url)
      when 'ics' then IcsFetcher.new.fetch(source.url)
      when 'api'
        # désactivé par défaut, à remettre quand ton client API sera final
        []
      else
        []
      end

    imported = 0
    items.each do |row|
      attrs = RawMapper.to_opportunity(row, source: source)
      rec = Opportunity.find_or_initialize_by(source: attrs[:source], external_id: attrs[:external_id])
      rec.assign_attributes(attrs)
      rec.save!
      imported += 1
    end

    source.update!(last_error: nil, last_run_at: Time.current)
    Rails.logger.info("[sources] OK #{source.name} — #{imported} éléments")
    imported
  rescue => e
    source.update!(last_error: "#{e.class}: #{e.message}", last_run_at: Time.current) rescue nil
    Rails.logger.error("[sources] KO #{source.name} — #{e.class}: #{e.message}")
    0
  end
end
