require 'faraday'
require 'feedjira'
require 'rss'
require 'uri'
require 'digest/sha1'

class RssFetcher
  def fetch(url)
    conn = Faraday.new do |f|
      f.headers['User-Agent'] = 'DeclicBot/1.0 (+https://declic.local)'
      f.options.timeout = 10
      f.options.open_timeout = 5
      f.follow_redirects = true if f.respond_to?(:follow_redirects=)
    end

    resp = conn.get(url)
    body = resp.body.to_s

    # Si on a reçu du HTML (souvent une page web ou une erreur), on stoppe proprement
    if resp.headers['content-type'].to_s.include?('text/html') || body.lstrip.start_with?('<!DOCTYPE html', '<html')
      raise "Not a feed (HTML received)"
    end

    begin
      feed = Feedjira.parse(body)
      return Array(feed.entries).map { |e| map_feedjira(e) }
    rescue Feedjira::NoParserAvailable
      # Fallback: parseur RSS de la lib standard
      begin
        rss = RSS::Parser.parse(body, false)
        items = Array(rss&.items)
        return items.map { |i| map_rss_std(i) }
      rescue => e
        raise "RSS stdlib parse failed: #{e.class} #{e.message}"
      end
    end
  end

  private

  def map_feedjira(e)
    {
      external_id: Digest::SHA1.hexdigest(e.url.to_s),
      title:       e.title.to_s.strip,
      description: (e.summary || e.content).to_s,
      organization: (URI(e.url).host rescue nil),
      starts_at:    e.published,
      source_url:   e.url.to_s
    }
  end

  def map_rss_std(item)
    link = if item.respond_to?(:link) && item.link.respond_to?(:href)
             item.link.href
           else
             item.link.to_s
           end

    {
      external_id: Digest::SHA1.hexdigest(link.to_s),
      title:       item.title.to_s.strip,
      description: (item.respond_to?(:summary) ? item.summary : item.respond_to?(:description) ? item.description : nil).to_s,
      organization: (URI(link).host rescue nil),
      starts_at:    (item.respond_to?(:pubDate) ? item.pubDate : (item.respond_to?(:dc_date) ? item.dc_date : nil)),
      source_url:   link.to_s
    }
  end
end