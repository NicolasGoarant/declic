class RawMapper
  def self.to_opportunity(h, source:)
    {
      source:      source.name,
      external_id: h[:external_id],
      title:       h[:title].to_s.strip.presence || 'Sans titre',
      description: h[:description].to_s,
      organization:h[:organization],
      location:    h[:location],
      starts_at:   safe_time(h[:starts_at]),
      ends_at:     safe_time(h[:ends_at]),
      latitude:    h[:latitude],
      longitude:   h[:longitude],
      category:    guess_category(h),
      is_active:   true,
      source_url:  h[:source_url],
      raw_payload: h
    }.compact
  end

  def self.safe_time(t)
    t.respond_to?(:to_time) ? t.to_time : (Time.parse(t.to_s) rescue nil)
  end

  def self.guess_category(h)
    t = "#{h[:title]} #{h[:description]}".downcase
    return 'formation'   if t.match?(/formation|atelier|bootcamp|cours|apprendre/)
    return 'benevolat'   if t.match?(/bénévol|solidar|entraide|aide|don/)
    return 'entreprendre'if t.match?(/entrepren|incubateur|startup|projet/)
    return 'rencontres'  if t.match?(/rencontre|café|communaut|réseau|club|soirée/)
    'benevolat'
  end
end
