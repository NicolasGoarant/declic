module ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  CTA_REGEX = /(et moi,\s*comment\s*je\s*peux\s*avoir\s*le\s*d[ée]clic)/i

  def md(text)
    raw = text.to_s

    html =
      if defined?(Commonmarker)
        # ✅ API correcte (1 seul argument)
        Commonmarker.commonmark_to_html(raw)
      else
        ERB::Util.html_escape(raw).gsub("\n", "<br>")
      end

    safe = sanitize(
      html,
      tags: %w[h1 h2 h3 h4 h5 h6 p br hr strong em a ul ol li blockquote code pre],
      attributes: %w[href title target rel class]
    )

    decorate_md_cta(safe)
  end

  private

  def decorate_md_cta(safe_html)
    require "nokogiri"

    frag = Nokogiri::HTML::DocumentFragment.parse(safe_html)

    frag.css("h3").each do |h|
      next unless h.text.match?(CTA_REGEX)

      h["class"] = [h["class"], "md-cta-title"].compact.join(" ")

      wrapper = Nokogiri::XML::Node.new("div", frag)
      wrapper["class"] = "md-cta"

      node = h.next_sibling
      while node
        break if node.element? && node.name.match?(/^h[1-6]$/)
        nxt = node.next_sibling
        wrapper.add_child(node)
        node = nxt
      end

      h.add_next_sibling(wrapper) if wrapper.children.any?
    end

    frag.to_html.html_safe
  end
end
