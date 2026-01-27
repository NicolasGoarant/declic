module ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  CTA_REGEX = /(et moi,\s*comment\s*je\s*peux\s*avoir\s*le\s*d[ée]clic)/i

  def md(text)
    return "" if text.blank?

    # 1. Conversion Markdown -> HTML via Kramdown
    # On force l'utilisation de Kramdown qui est présent dans ton Gemfile
    html_output = Kramdown::Document.new(text.to_s, input: 'GFM').to_html

    # 2. Nettoyage sécurisé
    # On s'assure que Rails ne supprime pas les balises <strong> ou <h3>
    safe_html = sanitize(
      html_output,
      tags: %w[h1 h2 h3 h4 h5 h6 p br hr strong em a ul ol li blockquote code pre div span],
      attributes: %w[href title target rel class style]
    )

    # 3. Application de ton design CTA
    decorate_md_cta(safe_html).html_safe
  end

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
