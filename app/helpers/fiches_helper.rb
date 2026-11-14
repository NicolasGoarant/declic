# Pages publiques d'une Opportunité et d'une Belle Histoire (layout « fiche », même
# palette que /labo/accueil). Maquettes : docs/maquettes/declic-maquette-fiche-*-v1.png.
module FichesHelper
  MOIS = Opportunity::MOIS

  def categorie_de(fiche)
    cle = fiche.is_a?(Story) ? Categorie::HISTOIRES : fiche.category
    Categorie.trouver(cle) || Categorie.trouver(Categorie::HISTOIRES)
  end

  # Fond du visuel de repli d'une fiche sans photo : la couleur de la catégorie, éclaircie, avec un halo blanc
  # derrière l'icône. Source unique : page publique (fiches/_galerie) et vignettes de la galerie d'administration.
  def fond_repli(couleur)
    "background: radial-gradient(circle at 50% 45%, #fff 0 22%, transparent 60%), color-mix(in srgb, #{couleur} 28%, #fff)"
  end

  # Visuel de repli complet (fond + icône de la catégorie), pour les vignettes. `cle` : clé de Categorie ;
  # nil si la fiche n'est pas classée (l'appelant montre alors un pavé neutre).
  def visuel_repli(cle, taille: 56)
    cat = Categorie.trouver(cle)
    return unless cat

    tag.span(icone_categorie(cat, taille: taille, style: "filter: drop-shadow(0 4px 8px rgba(29,26,43,.2))"),
             class: "visuel-repli", style: "#{fond_repli(cat.couleur)}; display:grid; place-items:center; width:100%; height:100%")
  end

  # Illustration de repli d'une carte de la galerie d'administration : aplats et pictogrammes simples, une scène par
  # catégorie (et une pour les Belles Histoires), aux couleurs de Categorie. Jamais d'image de source. `cle` absente ou
  # inconnue (candidat non classé) : scène grise neutre. SVG en ligne, sans script ni ressource externe.
  def illustration_repli(cle)
    cat = Categorie.trouver(cle)
    base = cat&.couleur || "#94A3B8"
    fond  = melange_hex(base, "#FFFFFF", 0.72)
    clair = melange_hex(base, "#FFFFFF", 0.45)
    franc = base
    fonce = melange_hex(base, "#1D1A2B", 0.35)
    blanc = "#FFFFFF"
    corps = case cat&.cle
            when "ecologie"
              %(<circle cx="250" cy="48" r="22" fill="#{blanc}"/><path d="M0 150 Q80 96 170 140 T320 120 V180 H0Z" fill="#{clair}"/><path d="M0 168 Q110 128 210 160 T320 152 V180 H0Z" fill="#{franc}"/><rect x="92" y="88" width="9" height="40" rx="3" fill="#{fonce}"/><circle cx="96" cy="76" r="26" fill="#{franc}"/><circle cx="82" cy="90" r="16" fill="#{clair}"/><circle cx="112" cy="88" r="15" fill="#{fonce}" opacity=".85"/>)
            when "entreprendre"
              %(<rect x="70" y="112" width="34" height="42" rx="4" fill="#{clair}"/><rect x="120" y="86" width="34" height="68" rx="4" fill="#{franc}"/><rect x="170" y="58" width="34" height="96" rx="4" fill="#{fonce}"/><path d="M72 84 L128 52 L172 36" fill="none" stroke="#{blanc}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><path d="M158 30 L180 34 L172 56Z" fill="#{blanc}"/><circle cx="252" cy="62" r="26" fill="#{blanc}"/><rect x="244" y="86" width="16" height="10" rx="3" fill="#{clair}"/><path d="M252 50 V66 M244 58 H260" stroke="#{franc}" stroke-width="4" stroke-linecap="round"/>)
            when "formation"
              %(<path d="M160 142 L60 120 V58 L160 80Z" fill="#{clair}"/><path d="M160 142 L260 120 V58 L160 80Z" fill="#{franc}"/><path d="M160 80 V142" stroke="#{blanc}" stroke-width="4"/><path d="M80 72 L142 86 M80 88 L142 102 M178 86 L240 72 M178 102 L240 88" stroke="#{blanc}" stroke-width="4" stroke-linecap="round" opacity=".8"/><path d="M160 20 L218 40 L160 58 L102 40Z" fill="#{fonce}"/><path d="M130 52 V68 Q160 82 190 68 V52" fill="#{fonce}" opacity=".85"/><path d="M214 42 V66" stroke="#{blanc}" stroke-width="3"/><circle cx="214" cy="70" r="5" fill="#{blanc}"/>)
            when "benevolat"
              %(<path d="M160 138 C96 98 90 56 126 50 C144 47 156 58 160 68 C164 58 176 47 194 50 C230 56 224 98 160 138Z" fill="#{franc}"/><path d="M160 138 C128 118 112 96 118 78" fill="none" stroke="#{blanc}" stroke-width="5" stroke-linecap="round" opacity=".55"/><circle cx="76" cy="100" r="14" fill="#{fonce}"/><path d="M52 150 Q76 112 100 150Z" fill="#{fonce}"/><circle cx="244" cy="100" r="14" fill="#{clair}"/><path d="M220 150 Q244 112 268 150Z" fill="#{clair}"/>)
            when "pratiquer"
              %(<path d="M158 36 C98 36 58 68 58 104 C58 136 92 146 118 142 C140 138 134 122 150 120 C176 118 178 148 214 140 C256 130 276 92 252 62 C234 42 198 36 158 36Z" fill="#{franc}"/><circle cx="104" cy="82" r="11" fill="#{blanc}"/><circle cx="148" cy="64" r="11" fill="#{fonce}"/><circle cx="198" cy="72" r="11" fill="#{clair}"/><circle cx="228" cy="104" r="11" fill="#{blanc}" opacity=".85"/><path d="M236 150 L282 70" stroke="#{fonce}" stroke-width="8" stroke-linecap="round"/><path d="M276 80 L290 56 L300 62 L284 86Z" fill="#{blanc}"/>)
            when "decouvrir"
              %(<path d="M40 70 L110 52 L170 74 L240 52 L282 66 V146 L240 132 L170 154 L110 132 L40 150Z" fill="#{clair}"/><path d="M110 52 V132 M170 74 V154 M240 52 V132" stroke="#{blanc}" stroke-width="3" opacity=".8"/><path d="M60 112 Q100 84 140 112 T230 100" fill="none" stroke="#{blanc}" stroke-width="4" stroke-dasharray="2 9" stroke-linecap="round"/><path d="M200 22 C170 22 156 44 156 62 C156 86 200 118 200 118 C200 118 244 86 244 62 C244 44 230 22 200 22Z" fill="#{franc}"/><circle cx="200" cy="60" r="14" fill="#{blanc}"/>)
            when Categorie::HISTOIRES
              %(<path d="M62 34 H258 A16 16 0 0 1 274 50 V116 A16 16 0 0 1 258 132 H168 L128 160 V132 H62 A16 16 0 0 1 46 116 V50 A16 16 0 0 1 62 34Z" fill="#{franc}"/><path d="M96 62 H134 V92 Q134 106 114 108 M96 62 V92 H114" fill="none" stroke="#{blanc}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><path d="M162 62 H200 V92 Q200 106 180 108 M162 62 V92 H180" fill="none" stroke="#{blanc}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><circle cx="238" cy="84" r="12" fill="#{blanc}" opacity=".85"/>)
            else
              %(<rect x="96" y="40" width="128" height="100" rx="12" fill="#{clair}"/><circle cx="160" cy="86" r="22" fill="#{blanc}"/><text x="160" y="97" text-anchor="middle" font-size="30" font-weight="700" fill="#{fonce}" font-family="system-ui,sans-serif">?</text>)
            end
    tag.svg(raw(%(<rect width="320" height="180" fill="#{fond}"/>#{corps})), viewBox: "0 0 320 180", preserveAspectRatio: "xMidYMid slice",
            class: "illustration-repli", role: "img", "aria-hidden": "true", focusable: "false")
  end

  # Mélange de deux couleurs « #RRGGBB » : `part` de la seconde, le reste de la première.
  def melange_hex(hexa, autre, part)
    a = hexa.delete("#").scan(/../).map { |c| c.to_i(16) }
    b = autre.delete("#").scan(/../).map { |c| c.to_i(16) }
    "#" + a.zip(b).map { |x, y| format("%02X", (x * (1 - part) + y * part).round) }.join
  end

  # Texte noir ou blanc selon la clarté de la couleur (même règle que diorama#encreSur).
  def encre_sur(hexa)
    r, v, b = [ 1, 3, 5 ].map { |i| hexa[i, 2].to_i(16) / 255.0 }
                         .map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    0.2126 * r + 0.7152 * v + 0.0722 * b > 0.4 ? "#1d1a2b" : "#ffffff"
  end

  def date_longue(date) = "#{date.day} #{MOIS[date.month - 1]} #{date.year}"

  # « Publiée le 24 janvier 2026 · il y a 3 jours ».
  def publication(fiche)
    moment = (fiche.try(:published_at) || fiche.created_at).in_time_zone(ConversionDates::FUSEAU).to_date
    "Publiée le #{date_longue(moment)} · #{il_y_a(moment)}"
  end

  def il_y_a(date)
    jours = (Time.current.in_time_zone(ConversionDates::FUSEAU).to_date - date).to_i
    case jours
    when ..0 then "aujourd'hui"
    when 1 then "hier"
    when 2..59 then "il y a #{jours} jours"
    when 60..729 then "il y a #{jours / 30} mois"
    else "il y a #{jours / 365} ans"
    end
  end

  # Photos de la galerie dans l'ordre (photos_order), sinon l'image principale (upload ou URL).
  # Vide : la galerie montre l'icône de la catégorie sur fond coloré.
  def photos_galerie(fiche)
    urls = fiche.photos_ordonnees.map { |a| url_for(a) }
    urls = [ photo_de(fiche) ].compact if urls.empty?
    urls.each_with_index.map { |src, i| { src: src, alt: "#{fiche.title} — photo #{i + 1} sur #{urls.size}" } }
  end

  # [lieu, adresse] : « MJC Lillebonne, 14 rue du Cheval Blanc, 54000 Nancy » donne
  # ["MJC Lillebonne", "14 rue du Cheval Blanc, 54000 Nancy"]. Un lieu saisi (venue_name) l'emporte.
  def lieu_et_adresse(fiche)
    code = fiche.try(:postal_code).presence || fiche.try(:postcode).presence
    adresse = [ fiche.address.presence, [ code, fiche.city.presence ].compact.join(" ").presence ].compact.join(", ") if fiche.address.present?
    lieu = fiche.try(:venue_name).presence
    morceaux = fiche.location.to_s.split(",").map(&:strip).reject(&:empty?)
    if adresse.blank? && morceaux.any?
      if morceaux.size > 1 && !morceaux.first.match?(/\A\d/)
        lieu ||= morceaux.first
        adresse = morceaux.drop(1).join(", ")
      else
        adresse = morceaux.join(", ")
      end
    elsif adresse.present? && morceaux.size > 1 && !morceaux.first.match?(/\A\d/) && !adresse.include?(morceaux.first)
      lieu ||= morceaux.first
    end
    lieu = nil if lieu.present? && adresse.to_s.start_with?(lieu)
    [ lieu, adresse.presence ]
  end

  def google_maps_url(fiche)
    lieu, adresse = lieu_et_adresse(fiche)
    requete = [ lieu, adresse ].compact.join(", ").presence
    requete ||= "#{fiche.latitude},#{fiche.longitude}" if fiche.latitude.present? && fiche.longitude.present?
    return nil unless requete

    "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(requete)}"
  end

  def initiales(nom)
    nom.to_s.scan(/[[:alpha:]]+/).reject { |m| m.size < 2 && m != m.upcase }.first(2).map { |m| m[0].upcase }.join.presence || "?"
  end

  # Étiquettes de l'opportunité, plus « Gratuit » si is_free.
  def etiquettes(opportunity)
    liste = opportunity.tags.to_s.split(/[;,]/).map(&:strip).reject(&:empty?).uniq(&:downcase)
    liste << "Gratuit" if opportunity.is_free && liste.none? { |t| t.casecmp?("gratuit") }
    liste
  end

  def site_organisateur(opportunity)
    normaliser_url(opportunity.website.presence || opportunity.website_url.presence)
  end

  # Bouton du bloc d'action : bouton saisi, sinon lien externe ou site, sinon courriel.
  def action_opportunite(opportunity)
    if (url = normaliser_url(opportunity.cta_button_url))
      { texte: opportunity.cta_button_text.presence || "Je participe", url: url }
    elsif (url = normaliser_url(opportunity.external_url.presence || opportunity.website.presence))
      { texte: opportunity.cta_button_text.presence || "Je participe / Je m'inscris", url: url }
    elsif opportunity.contact_email.present?
      { texte: "Écrire à l'organisateur", url: "mailto:#{opportunity.contact_email.strip}" }
    end
  end

  def normaliser_url(valeur)
    s = valeur.to_s.strip
    return nil if s.empty?

    s = "https://#{s}" if s.match?(/\Awww\./i)
    s if s.match?(/\Ahttps?:\/\//i)
  end

  # Liens de partage (Facebook, X, LinkedIn) de l'URL canonique.
  def liens_partage(url, titre)
    u = ERB::Util.url_encode(url)
    {
      facebook: "https://www.facebook.com/sharer/sharer.php?u=#{u}",
      x: "https://twitter.com/intent/tweet?url=#{u}&text=#{ERB::Util.url_encode(titre)}",
      linkedin: "https://www.linkedin.com/sharing/share-offsite/?url=#{u}"
    }
  end

  # Résumé de 150 caractères au plus pour Open Graph : texte brut, sans marqueurs d'images
  # ni syntaxe markdown.
  def resume_partage(texte)
    brut = strip_tags(texte.to_s)
             .gsub(/<!--.*?-->|___INLINE_PHOTO_\d_PLACEHOLDER___/m, " ")
             .gsub(/!\[[^\]]*\]\([^)]*\)/, " ")
             .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')
             .gsub(/[#*_>`]+/, " ")
             .squish
    truncate(brut, length: 150, separator: " ", omission: "…")
  end

  # Image de couverture en URL absolue ; sans photo, l'image de repli de la catégorie.
  def image_partage(fiche)
    if (piece = fiche.couverture)
      return rails_blob_url(piece, host: request.base_url)
    end

    url = photo_de(fiche)
    return (url.start_with?("http") ? url : "#{request.base_url}#{url}") if url.present?

    nom = fiche.is_a?(Story) ? "fallback-story.jpg" : "fallback-opportunity-#{fiche.category}.jpg"
    nom = "fallback-opportunity.jpg" unless fiche.is_a?(Story) || Opportunity::CATEGORIES.include?(fiche.category)
    image_url(nom)
  end

  # Description d'une opportunité, markdown léger et photos inline (<!-- IMAGE_n -->) comme
  # l'ancienne fiche : texte court (< 500 caractères) → photos en pleine largeur ; texte long →
  # gauche, droite, pleine largeur.
  def description_opportunite(opportunity)
    texte = opportunity.description.to_s
    court = texte.gsub(/<!--.*?-->/, "").strip.length < 500
    positions = %w[left right full]
    photos = (1..3).filter_map do |i|
      piece = opportunity.public_send("inline_image_#{i}")
      next unless piece.attached?

      { url: url_for(piece), legende: opportunity.public_send("inline_caption_#{i}"), position: positions[i - 1] }
    end
    photos.each_with_index do |photo, index|
      marqueur = "<!-- IMAGE_#{index + 1} -->"
      next unless texte.include?(marqueur)

      legende = photo[:legende].present? ? %(<figcaption class="inline-photo-caption">#{ERB::Util.html_escape(photo[:legende])}</figcaption>) : ""
      classe = court ? "inline-photo-stack" : "inline-photo-#{photo[:position]}"
      figure = %(<figure class="#{classe}"><img src="#{photo[:url]}" alt="Photo #{index + 1}" loading="lazy" />#{legende}</figure>)
      texte = texte.sub(marqueur, "\n\n#{figure}\n\n")
    end
    render_opportunity_body(texte)
  end
end
