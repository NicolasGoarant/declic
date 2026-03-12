# app/helpers/opportunities_helper.rb
module OpportunitiesHelper
  include ActionView::Helpers::SanitizeHelper

  # 1) URL externe prioritaire (normalisée https://…)
  def ext_url_for(op)
    candidates = %i[
      external_url url link_url website website_url
      registration_url signup_url source_url info_url more_info_url
    ]
    raw = candidates.lazy.map { |m| op.respond_to?(m) && op.public_send(m) }.find { |x| x.present? }
    normalize_http(raw)
  end

  def normalize_http(u)
    return nil if u.blank?
    s = u.to_s.strip
    s = "https://#{s}" if s =~ /\Awww\./i
    s if s =~ /\Ahttps?:\/\//i
  end

  # 2) Lien Google Calendar si starts_at(/ends_at)
  def gcal_url(op)
    return unless op.respond_to?(:starts_at) && op.starts_at.present?
    s = op.starts_at.utc.strftime('%Y%m%dT%H%M%SZ')
    e = (op.try(:ends_at) || op.starts_at + 1.hour).utc.strftime('%Y%m%dT%H%M%SZ')
    q = {
      action:  'TEMPLATE',
      text:    op.title,
      dates:   "#{s}/#{e}",
      details: strip_tags(op.description.to_s),
      location: op.location
    }.to_query
    "https://www.google.com/calendar/render?#{q}"
  end

  # 3) Lien Google Maps sur l'adresse
  def maps_url(op)
    return unless op.location.present?
    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(op.location.to_s)}"
  end

  # ----------------------------- MARKDOWN RENDERING -----------------------------

  # Convertit **gras**, *italique* et [lien](https://...) après échappement HTML
  def inline_format_opportunity(text)
    s = ERB::Util.html_escape(text.to_s)

    # Liens [label](http/https)
    s = s.gsub(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/i) do
      label = Regexp.last_match(1)
      href  = Regexp.last_match(2)
      %Q(<a href="#{href}" target="_blank" rel="noopener nofollow" class="text-blue-600 hover:underline">#{ERB::Util.html_escape(label)}</a>)
    end

    # **gras**
    s = s.gsub(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # *italique* (éviter de matcher dans **…**)
    s = s.gsub(/(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)/) { "<em>#{Regexp.last_match(1)}</em>" }

    s
  end

  # Emoji par défaut pour les titres d'opportunities
  def emoji_for_opportunity(title)
    key = title.to_s.downcase
    case
    when key.include?('craindre') || key.include?('panne')          then '💡'
    when key.include?('atelier') || key.include?('participatif')    then '🛠️'
    when key.include?('mains') || key.include?('cambouis')          then '🔧'
    when key.include?('mettre')                                     then '👍'
    else '📌'
    end
  end

  # Détection émoji en début de ligne
  EMOJI_START_RX = /\A[\p{Emoji}\u2600-\u27BF]/u

  # ----------------------------- NOUVEAU : SUPPORT IMAGES INLINE -----------------------------

  # Remplace les <!-- IMAGE_1 -->, <!-- IMAGE_2 -->, <!-- IMAGE_3 --> par les vraies images
  def replace_inline_images(text, opportunity)
    return text unless opportunity

    result = text.dup

    # IMAGE_1
    if opportunity.respond_to?(:inline_image_1) && opportunity.inline_image_1.attached?
      img_tag = render_inline_image(opportunity.inline_image_1, opportunity.inline_caption_1, 1)
      result.gsub!(/<!--\s*IMAGE_1\s*-->/, img_tag)
    end

    # IMAGE_2
    if opportunity.respond_to?(:inline_image_2) && opportunity.inline_image_2.attached?
      img_tag = render_inline_image(opportunity.inline_image_2, opportunity.inline_caption_2, 2)
      result.gsub!(/<!--\s*IMAGE_2\s*-->/, img_tag)
    end

    # IMAGE_3
    if opportunity.respond_to?(:inline_image_3) && opportunity.inline_image_3.attached?
      img_tag = render_inline_image(opportunity.inline_image_3, opportunity.inline_caption_3, 3)
      result.gsub!(/<!--\s*IMAGE_3\s*-->/, img_tag)
    end

    result
  end

  # Génère le HTML d'une image inline avec caption
  def render_inline_image(attachment, caption, index)
    img_url = url_for(attachment)

    # Alternance gauche/droite
    position_class = (index.odd? ? 'inline-photo-left' : 'inline-photo-right')

    html = %{
      <figure class="#{position_class}">
        <img src="#{img_url}" alt="#{ERB::Util.html_escape(caption || 'Photo')}" loading="lazy" />
        #{"<figcaption>#{ERB::Util.html_escape(caption)}</figcaption>" if caption.present?}
      </figure>
    }

    html
  end

  # ----------------------------- RENDU PRINCIPAL -----------------------------

  # Rendu principal du body d'une opportunity (avec support images inline)
  def render_opportunity_body(text)
    return "".html_safe if text.blank?

    # ÉTAPE 1 : Remplacer les <!-- IMAGE_X --> par les vraies images AVANT le parsing markdown
    text_with_images = replace_inline_images(text, @opportunity)

    # ÉTAPE 2 : Parser le markdown
    lines = text_with_images.to_s.split(/\r?\n/)
    html  = []
    in_list = false

    lines.each do |raw|
      line = raw.rstrip

      # Titres ### (avec émoji optionnel)
      if line =~ /\A[ \t]*###[ \t]+(.+)/
        title_raw = Regexp.last_match(1).strip

        # Détecter émoji au début (avec ou sans accolades)
        custom_emoji = nil
        title = title_raw

        # Pattern 1: {émoji} Titre
        if title_raw =~ /\A\{(.)\}[ \t]*(.+)\z/u
          potential = Regexp.last_match(1)
          rest = Regexp.last_match(2).strip
          # Vérifie que c'est bien un émoji
          if potential.ord >= 0x1F300 || potential =~ /[\p{Emoji}]/
            custom_emoji = potential
            title = rest  # SANS l'émoji
          end
        # Pattern 2: émoji Titre (émoji collé au texte)
        elsif title_raw =~ /\A(.)[ \t]*(.+)\z/u
          potential = Regexp.last_match(1)
          rest = Regexp.last_match(2).strip
          # Vérifie que c'est bien un émoji
          if potential.ord >= 0x1F300 || potential =~ /[\p{Emoji}]/
            custom_emoji = potential
            title = rest  # SANS l'émoji
          end
        end

        emoji = custom_emoji || emoji_for_opportunity(title)

        html << %(</ul>) if in_list
        in_list = false

        html << %(
          <h3 class="mt-6 mb-3 flex items-center gap-3 text-lg font-bold text-slate-900">
            <span class="inline-flex h-9 w-9 items-center justify-center rounded-full bg-emerald-100 text-xl">#{emoji}</span>
            <span class="font-bold">#{ERB::Util.html_escape(title)}</span>
          </h3>
        )
        next
      end

      # Titres en **gras:** (alternative à ###)
      if line =~ /\A\*\*(.+?)\*\*\s*:?\s*\z/
        bold_title = Regexp.last_match(1).strip

        # Générer émoji par défaut
        emoji = emoji_for_opportunity(bold_title)

        html << %(</ul>) if in_list
        in_list = false

        html << %(
          <h3 class="mt-6 mb-3 flex items-center gap-3 text-lg font-bold text-slate-900">
            <span class="inline-flex h-9 w-9 items-center justify-center rounded-full bg-emerald-100 text-xl">#{emoji}</span>
            <span class="font-bold">#{ERB::Util.html_escape(bold_title)}</span>
          </h3>
        )
        next
      end

      # Listes "- ..."
      if line =~ /\A-\s+(.+)/
        item = Regexp.last_match(1).strip
        unless in_list
          html << %(<ul class="list-disc pl-6 space-y-1 text-slate-700 mb-4">)
          in_list = true
        end
        html << %(<li>#{inline_format_opportunity(item)}</li>)
        next
      end

      # Ligne vide -> fermer liste si besoin
      if line.blank?
        if in_list
          html << %(</ul>)
          in_list = false
        end
        next
      end

      # Paragraphe OU balise HTML (figure) générée par replace_inline_images
      if in_list
        html << %(</ul>)
        in_list = false
      end

      # Si la ligne contient du HTML (comme <figure>), on la passe telle quelle
      if line =~ /<figure class="inline-photo/
        html << line
      else
        html << %(<p class="text-slate-700 leading-relaxed mb-4">#{inline_format_opportunity(line)}</p>)
      end
    end

    html << %(</ul>) if in_list
    html.join("\n").html_safe
  end
end
