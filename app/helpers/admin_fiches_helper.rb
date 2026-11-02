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

  JOURS_ABREGES = %w[dim. lun. mar. mer. jeu. ven. sam.].freeze
  MOIS_ABREGES = %w[janv. févr. mars avr. mai juin juil. août sept. oct. nov. déc.].freeze

  # « dim. 1er nov. » : jour abrégé, « 1er » pour le premier du mois, jour sans zéro, mois abrégé.
  def date_admin(date)
    return nil if date.nil?

    jour = date.day == 1 ? "1er" : date.day.to_s
    "#{JOURS_ABREGES[date.wday]} #{jour} #{MOIS_ABREGES[date.month - 1]}"
  end

  # Dates propres à l'événement : « mar. 3 nov. » ou « mar. 3 → jeu. 5 nov. » ; nil pour une fiche permanente.
  def periode_admin(opportunite)
    debut = opportunite.date_debut
    fin = opportunite.date_fin
    return nil if debut.nil? && fin.nil?
    return "jusqu'au #{date_admin(fin)}" if debut.nil?
    return date_admin(debut) if fin.nil? || fin == debut

    "#{date_admin(debut)} → #{date_admin(fin)}"
  end

  # Nom du lieu (le cas échéant) puis adresse postale complète : [nom, « rue, 54000 Nancy »].
  def lieu_admin(fiche)
    nom = fiche.try(:venue_name).presence || fiche.try(:location).presence
    ville = [fiche.postal_code.presence, fiche.city.presence].compact.join(" ")
    adresse = [fiche.address.presence, ville.presence].compact.join(", ")
    nom = nil if nom == adresse
    [nom, adresse.presence]
  end

  # Libellé et couleur de la catégorie de l'opportunité, pour le badge.
  def badge_categorie(opportunite)
    cat = Categorie.trouver(opportunite.category)
    [cat&.libelle || opportunite.category.to_s.humanize, cat&.couleur || "#64748b"]
  end
end
