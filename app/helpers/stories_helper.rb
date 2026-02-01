# app/helpers/stories_helper.rb
module StoriesHelper
  # ----------------------------- Emoji mapping (fallback) -----------------------------
  def emoji_for(title)
    key = title.to_s.downcase
    case
    when key.include?('projet')            then '🌿'
    when key.include?('parcours')          then '🚶‍♀️'
    when key.include?('vie du lieu') ||
         key.include?('vie du') ||
         key.include?('le lieu')           then '☕'
    when key.include?('carte') ||
         key.include?('menu')              then '🍰'
    when key.include?('inspirant') ||
         key.include?('pourquoi')          then '💡'
    when key.include?('récit')             then '👉'
    when key.include?('immersion')         then '👉'
    when key.include?('secret')            then '👉'
    else '👉'
    end
  end

  # ----------------------------- Inline Markdown sûr ---------------------------------
  # Convertit **gras**, *italique* et [lien](https://...) après échappement HTML.
  # ⚠️ NOUVEAU : Préserve les placeholders HTML pour photos inline
  def inline_format(text)
    s = ERB::Util.html_escape(text.to_s)

    # Liens [label](http/https)
    s = s.gsub(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/i) do
      label = Regexp.last_match(1)
      href  = Regexp.last_match(2)
      %Q(<a href="#{href}" target="_blank" rel="noopener nofollow">#{ERB::Util.html_escape(label)}</a>)
    end

    # **gras**
    s = s.gsub(/\*\*(.+?)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # *italique* (éviter de matcher dans **…**)
    s = s.gsub(/(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)/) { "<em>#{Regexp.last_match(1)}</em>" }

    s
  end

  # ----------------------------- Images Markdown -------------------------------------
  # Gère ![alt](src) -> <figure><img><figcaption>
  def render_image_line(md_line)
    return nil unless md_line =~ /\A!\[(.*?)\]\((.*?)\)\s*\z/
    alt = Regexp.last_match(1).to_s.strip
    src = Regexp.last_match(2).to_s.strip
    src = (src =~ /\Ahttps?:\/\//i) ? src : asset_path(src)

    %Q(
      <figure class="story-img my-4">
        <img src="#{src}" alt="#{ERB::Util.html_escape(alt)}" loading="lazy" class="rounded-xl shadow-md w-full h-auto object-cover">
        <figcaption class="mt-2 text-sm text-slate-600">#{ERB::Util.html_escape(alt)}</figcaption>
      </figure>
    )
  end

  # ----------------------------- Détection émoji en début de ligne -------------------
  EMOJI_START_RX = /\A[\p{Emoji}\u2600-\u27BF]/u

  # Ajoute un émoji "pratique" uniquement si la ligne n'en possède pas déjà
  # DÉSACTIVÉ pour les paragraphes normaux - seulement pour infos pratiques
  def auto_emoji_line(line)
    l = line.to_s
    return l if l.strip.empty?
    return l if l.lstrip =~ EMOJI_START_RX

    # Mots-clés de bas de page / infos pratiques UNIQUEMENT
    lowered = l.downcase
    if lowered.start_with?('adresse')
      "📍 #{l}"
    elsif lowered.start_with?('crédit photo') || lowered.start_with?('crédit photo') || lowered.start_with?('crédit photo')
      "📸 #{l}"
    elsif lowered.start_with?('source')
      "📰 #{l}"
    elsif lowered.start_with?('contact')
      "✉️ #{l}"
    else
      # NE PLUS AJOUTER D'ÉMOJI PAR DÉFAUT SUR LES PARAGRAPHES NORMAUX
      l
    end
  end

  # ----------------------------- Rendu principal -------------------------------------
  # Markdown light :
  # - Titres "### ..." avec émoji saisi par l'auteur (🌿 Titre ou {🌿} Titre) sinon fallback emoji_for
  # - Listes "- ..."
  # - Bloc "**À retenir**" => liste à checkmarks
  # - Paragraphes + inline_format
  # - Images Markdown ![alt](src)
  # ⚠️ NOUVEAU : Préserve les placeholders ___INLINE_PHOTO_X_PLACEHOLDER___
  def render_story_body(text)
    return "".html_safe if text.blank?

    lines        = text.to_s.split(/\r?\n/)
    html         = []
    in_list      = false
    in_takeaways = false

    lines.each do |raw|
      line = raw.rstrip

      # ⚠️ NOUVEAU : Détecter et préserver les placeholders de photos inline
      if line =~ /\A___INLINE_PHOTO_\d+_PLACEHOLDER___\z/
        html << %(</ul>) if in_list
        in_list = false
        html << line  # Garder le placeholder tel quel
        next
      end

      # Images Markdown standard
      if (img_html = render_image_line(line))
        html << %(</ul>) if in_list
        in_list = false
        html << img_html
        next
      end

      # Titres ### (avec émoji saisi par l'auteur optionnel)
      if line =~ /\A[ \t\u00A0\u2000-\u200B\u202F]*###[ \t\u00A0\u2000-\u200B\u202F]+(.+)/
        title_raw = Regexp.last_match(1).strip

        # 1) "### 🌿 Titre"
        # 2) "### {🌿} Titre"
        custom_emoji = nil
        title = title_raw

        if title_raw =~ /\A\{(?<em>[\p{Emoji}\u2600-\u27BF])\}[ \t]*(?<rest>.+)\z/u
          custom_emoji = Regexp.last_match(:em)
          title        = Regexp.last_match(:rest).strip
        elsif title_raw =~ /\A(?<em>[\p{Emoji}\u2600-\u27BF])[ \t]*(?<rest>.+)\z/u
          custom_emoji = Regexp.last_match(:em)
          title        = Regexp.last_match(:rest).strip
        end

        emoji = custom_emoji || emoji_for(title)

        html << %(</ul>) if in_list
        in_list = false
        in_takeaways = false

        html << %(
          <h3 class="mt-7 mb-3 flex items-center gap-3 text-xl font-semibold text-slate-900">
            <span class="text-2xl">#{emoji}</span>
            <span>#{ERB::Util.html_escape(title)}</span>
          </h3>
        )
        next
      end

      # Bloc "À retenir"
      if line =~ /\A\*\*À retenir\*\*/
        html << %(
          <h4 class="mt-6 mb-2 flex items-center gap-2 text-base font-semibold text-amber-900">
            <span class="inline-flex h-6 w-6 items-center justify-center rounded-full bg-amber-100 text-sm">📌</span>
            <span>À retenir</span>
          </h4>
        )
        in_takeaways = true
        html << %(</ul>) if in_list
        in_list = false
        next
      end

      # Listes "- ..."
      if line =~ /\A-\s+(.+)/
        item = Regexp.last_match(1).strip
        unless in_list
          if in_takeaways
            html << %(<ul class="pl-0 list-none space-y-1 text-slate-800">)
          else
            html << %(<ul class="list-disc pl-6 space-y-1 text-slate-700">)
          end
          in_list = true
        end
        if in_takeaways
          html << %(<li class="flex items-start gap-2"><span class="mt-0.5 text-emerald-600">✓</span><span>#{inline_format(item)}</span></li>)
        else
          html << %(<li>#{inline_format(item)}</li>)
        end
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

      # Paragraphe
      if in_list
        html << %(</ul>)
        in_list = false
      end

      # Émoji auto SEULEMENT pour les lignes d'infos pratiques (Adresse, Contact, Source)
      formatted_line = auto_emoji_line(line)

      html << %(<p class="text-slate-800 leading-relaxed">#{inline_format(formatted_line)}</p>)
    end

    html << %(</ul>) if in_list
    html.join("\n").html_safe
  end

  # ----------------------------- Utilitaires -----------------------------------------
  def safe_excerpt(text, words: 25)
    text.to_s.split(/\s+/).first(words).join(" ")
  end
end
