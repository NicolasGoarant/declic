# Pages publiques d'une Opportunité et d'une Belle Histoire (layout « fiche », même
# palette que /labo/accueil). Maquettes : docs/maquettes/declic-maquette-fiche-*-v1.png.
module FichesHelper
  MOIS = Opportunity::MOIS

  def categorie_de(fiche)
    cle = fiche.is_a?(Story) ? Categorie::HISTOIRES : fiche.category
    Categorie.trouver(cle) || Categorie.trouver(Categorie::HISTOIRES)
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
