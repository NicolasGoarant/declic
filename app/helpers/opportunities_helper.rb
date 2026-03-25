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

  # Emoji intelligent pour les titres d'opportunities - logique large
  def emoji_for_opportunity(title)
    key = title.to_s.downcase

    # Catégorie 1: Santé & Médical
    return '🏥' if key =~ /(médic|santé|soin|hôpit|clinique|patient|thérap|pharmac)/
    return '🔬' if key =~ /(recherch|innov|technolog|scientif|lab|découvert)/

    # Catégorie 2: Écologie & Environnement
    return '🌱' if key =~ /(écolo|vert|nature|bio|durable|environn|planète|climat)/
    return '♻️' if key =~ /(recycl|déchet|économie circulaire|réutilis|circular|compost)/
    return '🌍' if key =~ /(écosystème|biodiversit|terre|monde|global|planétaire)/
    return '⚡' if key =~ /(énergie|électri|solaire|renouvel|photovolt|éolien)/

    # Catégorie 3: Entrepreneuriat & Business
    return '🚀' if key =~ /(projet|lance|créa|démarre|startup|entrepren|business|idée)/
    return '💰' if key =~ /(financ|levée|invest|fond|capital|budget|subvent|argent)/
    return '🎯' if key =~ /(object|ambiti|envergure|stratég|vision|mission|but)/
    return '📈' if key =~ /(croissan|progress|avanc|évolu|développ|expansion|croît)/
    return '🤝' if key =~ /(réseau|partena|collabor|coopéra|allianc|ensembl|collectif)/
    return '👨‍💼' if key =~ /(expert|conseil|accompagn|mentor|coach|guid|assist)/

    # Catégorie 4: Social & Solidarité
    return '❤️' if key =~ /(solidai|social|entraid|partag|générosi|don de soi)/
    return '🤲' if key =~ /(bénévol|don\b|aide|soutien|gratuit|volontai)/
    return '🏘️' if key =~ /(local|territoir|quartier|proximité|voisin|commune)/
    return '👥' if key =~ /(commun|group|collecti|citoyen|participa|démocrat)/

    # Catégorie 5: Formation & Éducation
    return '📚' if key =~ /(formation|cours|apprentiss|étud|enseign|pédagog|école)/
    return '🎓' if key =~ /(diplôm|certif|qualif|compétenc|savoir|connaissance)/
    return '👨‍🏫' if key =~ /(formateur|professeur|mentor|tuteur|enseignant)/

    # Catégorie 6: Événements & Culture
    return '📅' if key =~ /(événement|rendez-vous|date|inscri|programm|agenda)/
    return '🎭' if key =~ /(festival|concert|spectacl|cultur|artist|théâtre|scène)/
    return '🎉' if key =~ /(fête|célébr|inaug|lancement|gala|soirée)/

    # Catégorie 7: Réparation & Technique
    return '🔧' if key =~ /(répar|fix|dépann|mainten|entretien|restaur)/
    return '🛠️' if key =~ /(atelier|bricolag|fabrication|construc|manuel|pratique)/
    return '🏭' if key =~ /(production|usine|fabrique|manufactur|industr)/

    # Catégorie 8: Transport & Mobilité
    return '🚗' if key =~ /(voiture|auto|véhicul|condui|garage|mobilité)/
    return '🚂' if key =~ /(train|rail|ferroviair|tram|métro|transport public)/
    return '🚴' if key =~ /(vélo|cycl|piste|deux-roues)/

    # Catégorie 9: Alimentation
    return '🍽️' if key =~ /(restaurant|cuisine|chef|gastronom|repas|manger)/
    return '🌾' if key =~ /(agricul|ferme|paysan|maraîch|culture|récolte)/
    return '🥖' if key =~ /(boulang|pain|artisan|pâtiss)/

    # Catégorie 10: Problèmes & Solutions
    return '💡' if key =~ /(idée|solution|astuce|conseil|réponse|trouvaille|déclic)/
    return '⚠️' if key =~ /(problème|difficulté|défi|obstacle|crainte|peur|risque)/
    return '✨' if key =~ /(nouveau|nouveau|innov|origin|unique|inédit|révolu)/

    # Catégorie 11: Impact & Résultats
    return '🌟' if key =~ /(impact|effet|résultat|réussite|succès|performance)/
    return '🎁' if key =~ /(bonus|avantage|bénéfice|gain|offre|cadeau)/
    return '📊' if key =~ /(données|statistique|chiffre|mesure|indicateur)/

    # Catégorie 12: Temps & Durée
    return '⏰' if key =~ /(horaire|heure|temps|durée|planning|calendrier)/
    return '📆' if key =~ /(semaine|mois|année|période|saison|trimestre)/

    # Catégorie 13: Questions
    return '❓' if key =~ /(pourquoi|comment|quel|qui|quoi|où|quand|\?)/
    return '🔍' if key =~ /(saviez-vous|découvr|explor|cherch|trouv)/

    # Fallback intelligent basé sur le sentiment général
    return '🎯' if key =~ /(pour|vers|à|de|du|des|le|la|les|un|une)/ && key.length > 15

    # Dernier fallback
    '📌'
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
          <h3 style="margin-top:1.5rem;margin-bottom:0.75rem;display:flex;align-items:center;gap:0.75rem;font-size:1.1rem;font-weight:700;color:#0f172a;">
            <span style="display:inline-flex;width:2.25rem;height:2.25rem;align-items:center;justify-content:center;border-radius:9999px;background:#d1fae5;font-size:1.1rem;flex-shrink:0;">#{emoji}</span>
            <span style="font-weight:700;">#{ERB::Util.html_escape(title)}</span>
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
          <h3 style="margin-top:1.5rem;margin-bottom:0.75rem;display:flex;align-items:center;gap:0.75rem;font-size:1.1rem;font-weight:700;color:#0f172a;">
            <span style="display:inline-flex;width:2.25rem;height:2.25rem;align-items:center;justify-content:center;border-radius:9999px;background:#d1fae5;font-size:1.1rem;flex-shrink:0;">#{emoji}</span>
            <span style="font-weight:700;">#{ERB::Util.html_escape(bold_title)}</span>
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
