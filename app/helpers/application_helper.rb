module ApplicationHelper
  # ----- Assets -----
  def asset_exists?(logical_path)
    if Rails.application.config.assets.compile
      !!Rails.application.assets&.find_asset(logical_path)
    else
      Rails.application.assets_manifest.assets.key?(logical_path)
    end
  end

  # ----- Markdown rendering (robuste) -----
  #
  # Utilise Kramdown si disponible (gem 'kramdown' / 'kramdown-parser-gfm').
  # Sinon, fallback sobre : auto_link + simple_format.
  #
  # Sécurisation par sanitize avec liste blanche (img, a, h1..h4, etc.).
  def md(text)
    str = text.to_s

    html =
      if defined?(Kramdown)
        Kramdown::Document.new(str, input: "GFM").to_html
      else
        # Fallback très simple (pas de rendu d'images Markdown ici)
        # pour éviter tout crash si la gem n'est pas installée.
        simple_format(ERB::Util.h(str))
      end

    sanitize(
      html,
      tags: %w[h1 h2 h3 h4 p br strong em b i a ul ol li blockquote img code pre hr span],
      attributes: %w[href src alt title target rel class]
    )
  end

  # ----- Retirer le Markdown (pour les chapeaux et metas) -----
  def strip_markdown(text)
    html =
      if defined?(Kramdown)
        Kramdown::Document.new(text.to_s, input: "GFM").to_html
      else
        ERB::Util.h(text.to_s)
      end

    # On retire les balises pour obtenir un plain-text propre.
    ActionView::Base.full_sanitizer.sanitize(html)
  end
end
