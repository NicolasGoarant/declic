module StoriesHelper
  def emoji_for(title)
    key = title.to_s.downcase
    case
    when key.include?('déclic')           then '💡'
    when key.include?('projet')           then '🧭'
    when key.include?('proposition')      then '🧩'
    when key.include?('expérience')       then '✨'
    when key.include?('défi') || key.include?('obstacle') then '⚡'
    when key.include?('impact')           then '📍'
    when key.include?('coulisses')        then '🔧'
    when key.include?('virage')           then '🔄'
    when key.include?('signature')        then '⭐'
    when key.include?('montée')           then '📈'
    when key.include?('boutique')         then '🛒'
    when key.include?('métier')           then '🧰'
    when key.include?('concept')          then '🧠'
    else '👉'
    end
  end

  # Markdown light -> HTML (### titres, **À retenir**, listes "- ")
  # Sans encadré pour "À retenir" ; bullets avec ✓
  def render_story_body(text)
    return "".html_safe if text.blank?

    lines = text.to_s.split(/\r?\n/)
    html  = []
    in_list = false
    in_takeaways = false

    lines.each do |raw|
      line = raw.rstrip

      if line =~ /\A###\s+(.+)/
        title = Regexp.last_match(1).strip
        emoji = emoji_for(title)
        # ferme blocs en cours
        if in_list
          html << %(</ul>)
          in_list = false
        end
        if in_takeaways
          in_takeaways = false
        end
        html << %(
          <h3 class="mt-7 mb-3 flex items-center gap-3 text-xl font-semibold text-slate-900">
            <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-violet-600/10 text-lg">#{emoji}</span>
            <span>#{ERB::Util.html_escape(title)}</span>
          </h3>
        )
        next
      end

      if line =~ /\A\*\*À retenir\*\*/
        # pas d'encadré ; simple titre + on passe en mode "takeaways"
        html << %(
          <h4 class="mt-6 mb-2 flex items-center gap-2 text-base font-semibold text-amber-900">
            <span class="inline-flex h-6 w-6 items-center justify-center rounded-full bg-amber-100 text-sm">📌</span>
            <span>À retenir</span>
          </h4>
        )
        in_takeaways = true
        next
      end

      if line =~ /\A-\s+(.+)/
        item = Regexp.last_match(1).strip
        unless in_list
          # listes normales -> puces ; "À retenir" -> checkmarks et pas de puces par défaut
          if in_takeaways
            html << %(<ul class="pl-0 list-none space-y-1 text-slate-800">)
          else
            html << %(<ul class="list-disc pl-6 space-y-1 text-slate-700">)
          end
          in_list = true
        end
        if in_takeaways
          html << %(<li class="flex items-start gap-2"><span class="mt-0.5 text-emerald-600">✓</span><span>#{ERB::Util.html_escape(item)}</span></li>)
        else
          html << %(<li>#{ERB::Util.html_escape(item)}</li>)
        end
        next
      end

      if line.blank?
        if in_list
          html << %(</ul>)
          in_list = false
        end
        # on reste en mode "takeaways" tant qu'on n'a pas vu un nouveau titre
        next
      end

      if in_list
        html << %(</ul>)
        in_list = false
      end

      html << %(<p class="text-slate-800 leading-relaxed">#{ERB::Util.html_escape(line)}</p>)
    end

    html << %(</ul>) if in_list
    html.join("\n").html_safe
  end

  def safe_excerpt(text, words: 25)
    text.to_s.split(/\s+/).first(words).join(" ")
  end
end

