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

  # ----------------------------- Remplacement des placeholders d'images inline -------
  # Remplace les placeholders ___INLINE_PHOTO_X_PLACEHOLDER___ par la syntaxe Markdown ![caption](url)
  def replace_inline_photo_placeholders(text, story)
    return text if text.blank? || story.nil?

    processed = text.dup

    # Remplacer chaque placeholder par l'image correspondante
    (1..3).each do |i|
      placeholder = "___INLINE_PHOTO_#{i}_PLACEHOLDER___"
      next unless processed.include?(placeholder)

      inline_image = story.send("inline_image_#{i}")
      caption = story.send("inline_caption_#{i}").to_s.strip

      if inline_image.attached?
        # Générer l'URL de l'image via Active Storage
        begin
          # ✅ CORRECTION : Utiliser rails_blob_path au lieu de url_for pour éviter le problème de host
          image_url = Rails.application.routes.url_helpers.rails_blob_path(inline_image, only_path: true)
          # Créer la syntaxe Markdown avec caption
          markdown = "![#{caption}](#{image_url})"
          processed.gsub!(placeholder, markdown)
        rescue => e
          Rails.logger.error "Erreur lors de la génération de l'URL pour inline_image_#{i}: #{e.message}"
          # Supprimer le placeholder en cas d'erreur
          processed.gsub!(placeholder, "")
        end
      else
        # Supprimer le placeholder si pas d'image attachée
        processed.gsub!(placeholder, "")
      end
    end

    processed
  end

  # ----------------------------- Inline Markdown sûr ---------------------------------
  # Convertit **gras**, *italique* et [lien](https://...) après échappement HTML.
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

    # Gérer les différents types d'URLs
    img_src = if src.start_with?('/rails/active_storage', '/rails/blobs')
      # URL Active Storage - garder telle quelle
      src
    elsif src =~ /\Ahttps?:\/\//i
      # URL externe complète
      src
    else
      # Asset pipeline
      begin
        asset_path(src)
      rescue
        src
      end
    end

    %Q(
      <figure class="story-img my-4">
        <img src="#{img_src}" alt="#{ERB::Util.html_escape(alt)}" loading="lazy" class="rounded-xl shadow-md w-full h-auto object-cover" style="max-height: 500px;">
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
    elsif lowered.start_with?('crédit photo')
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
  # ✅ NOUVEAU : Remplace d'abord les placeholders ___INLINE_PHOTO_X_PLACEHOLDER___
  def render_story_body(text, story = nil)
    return "".html_safe if text.blank?

    # ✅ ÉTAPE 1 : Remplacer les placeholders par les vraies URLs Markdown
    processed_text = story ? replace_inline_photo_placeholders(text, story) : text

    lines        = processed_text.split(/\r?\n/)
    html         = []
    in_list      = false
    in_takeaways = false

    lines.each do |raw|
      line = raw.rstrip

      # Images Markdown (y compris celles générées depuis les placeholders)
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
