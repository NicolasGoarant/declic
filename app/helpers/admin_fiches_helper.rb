# Aides des listes d'administration (Opportunités et Belles Histoires) : vignette et extrait de chaque ligne.
module AdminFichesHelper
  EXTRAIT_ADMIN_LONGUEUR = 140

  # URL de la vignette de Une : variante `mini` (128 px) de la couverture quand libvips la sert, sinon l'original,
  # sinon l'ancienne image (upload ou URL). nil sans image : la cellule montre alors un pavé vide.
  def vignette_admin_url(fiche)
    piece = fiche.couverture
    if piece&.variable? && AccueilHelper::VIPS_DISPONIBLE
      url_for(piece.variant(AccueilHelper::VARIANTES_PHOTO.fetch(:mini)))
    else
      photo_couverture(fiche)
    end
  rescue StandardError
    nil
  end

  # Début du texte de la fiche en texte brut (sans HTML ni syntaxe markdown), coupé proprement sur un mot.
  def extrait_admin(*textes)
    source = textes.find(&:present?)
    return nil if source.blank?

    brut = strip_tags(source.to_s)
             .gsub(/<!--.*?-->|___INLINE_PHOTO_\d_PLACEHOLDER___/m, " ")
             .gsub(/!\[[^\]]*\]\([^)]*\)/, " ")
             .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')
             .gsub(/[#*_>`]+/, " ")
             .squish
    brut.presence && truncate(brut, length: EXTRAIT_ADMIN_LONGUEUR, separator: " ", omission: "…")
  end

  # Dates propres à l'événement : « 3 nov. 2026 » ou « 3 → 5 nov. 2026 » ; nil pour une fiche permanente.
  def periode_admin(opportunite)
    debut = opportunite.date_debut
    fin = opportunite.date_fin
    return nil if debut.nil? && fin.nil?
    return "jusqu'au #{l(fin, format: '%d/%m/%Y')}" if debut.nil?
    return l(debut, format: "%d/%m/%Y") if fin.nil? || fin == debut

    "#{l(debut, format: '%d/%m/%Y')} → #{l(fin, format: '%d/%m/%Y')}"
  end
end
