raw =
  case source.kind.to_sym
  when :ics    then Fetchers::IcsFetcher.call(source)
  when :rss    then Fetchers::RssFetcher.call(source)
  when :jsonld
    out = Fetchers::JsonldEventsFetcher.call(source)
    # Fallback JSON-LD profond
    out = Fetchers::DeepJsonldFetcher.call(source) if out.empty?
    # Routeurs spécifiques par domaine
    host = URI.parse(source.url).host rescue ""
    if out.empty? && host =~ /nancy\.cci\.fr/
      out = Fetchers::CciNancyFetcher.call(source)
    end
    if out.empty? && host =~ /lorr-up\.fr/
      out = Fetchers::LorrupFetcher.call(source)
    end
    out
  else
    []
  end


