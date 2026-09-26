# Données de la page d'accueil diorama (/labo/accueil), mises en forme pour le contrôleur
# Stimulus `diorama`. Mêmes champs que l'export lu par la maquette v3 de nancy-3d.
module AccueilHelper
  def categories_pour_js
    Categorie::TOUTES.map do |c|
      { cle: c.cle, libelle: c.libelle, couleur: c.couleur,
        icone: image_path("#{c.icone}.png"), icone2x: image_path("#{c.icone}@2x.png") }
    end
  end

  # Opportunités puis Belles Histoires, en une seule liste de points. Les dates sont en ISO
  # (AAAA-MM-JJ) ou nulles : c'est le navigateur qui les compare à sa propre date du jour.
  def points_diorama(opportunites, histoires)
    opportunites.map { |o| point_opportunite(o) } + histoires.map { |s| point_histoire(s) }
  end

  def icone_categorie(categorie, taille:, **options)
    image_tag("#{categorie.icone}.png", srcset: { image_path("#{categorie.icone}@2x.png") => "2x" },
              width: taille, height: taille, alt: "", **options)
  end

  # Pictogrammes au trait (tracés Lucide, licence ISC), 24 × 24, couleur du texte.
  PICTOS = {
    carte: ["M14.1 5.55a2 2 0 0 0 1.8 0l3.65-1.83A1 1 0 0 1 21 4.62v12.76a1 1 0 0 1-.55.9l-4.55 2.27a2 2 0 0 1-1.8 0l-4.2-2.1a2 2 0 0 0-1.8 0l-3.65 1.83A1 1 0 0 1 3 19.38V6.62a1 1 0 0 1 .55-.9L8.1 3.45a2 2 0 0 1 1.8 0z", "M15 5.76v15", "M9 3.24v15"],
    chercher: [{ circle: { cx: 11, cy: 11, r: 8 } }, "m21 21-4.3-4.3"],
    coeur: ["M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"],
    proposer: [{ circle: { cx: 12, cy: 12, r: 10 } }, "M8 12h8", "M12 8v8"],
    plus: ["M5 12h14", "M12 5v14"],
    moins: ["M5 12h14"],
    profil: ["M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2", { circle: { cx: 12, cy: 7, r: 4 } }],
    cloche: ["M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9", "M10.3 21a1.94 1.94 0 0 0 3.4 0"],
    lieu: ["M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z", { circle: { cx: 12, cy: 10, r: 3 } }],
    chevron: ["m6 9 6 6 6-6"],
    viseur: [{ circle: { cx: 12, cy: 12, r: 7 } }, { circle: { cx: 12, cy: 12, r: 2.5 } }, "M12 2v3", "M12 19v3", "M2 12h3", "M19 12h3"],
    calendrier: [{ rect: { x: 3, y: 4, width: 18, height: 18, rx: 2 } }, "M16 2v4", "M8 2v4", "M3 10h18"],
    horloge: [{ circle: { cx: 12, cy: 12, r: 10 } }, "M12 6v6l4 2"],
    reglages: ["M21 4h-7", "M10 4H3", "M21 12h-9", "M8 12H3", "M21 20h-5", "M12 20H3", "M14 2v4", "M8 10v4", "M16 18v4"],
    recentrer: ["M3 11l19-9-9 19-2-8-8-2z"],
    signet: ["m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"],
    fleche: ["M5 12h14", "m12 5 7 7-7 7"],
    distance: ["m18 8 4 4-4 4", "M2 12h20", "m6 8-4 4 4 4"]
  }.freeze

  def picto(nom, taille: 20, **options)
    formes = PICTOS.fetch(nom).map do |forme|
      forme.is_a?(String) ? tag.path(d: forme) : tag.public_send(forme.keys.first, **forme.values.first)
    end
    tag.svg(safe_join(formes), width: taille, height: taille, viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width" => 2, "stroke-linecap" => "round",
            "stroke-linejoin" => "round", "aria-hidden" => "true", focusable: "false", **options)
  end

  # Upload Active Storage, sinon URL saisie ; nil quand il n'y a pas de photo (la fiche
  # montre alors l'icône de la catégorie, dans la même boîte).
  def photo_de(objet)
    return url_for(objet.image) if objet.image.attached?
    return nil if objet.image_url.blank?

    objet.image_url.match?(/\Ahttps?:\/\//i) ? objet.image_url : asset_path(objet.image_url)
  rescue StandardError
    nil
  end

  # La commune déclarée, sinon celle qui suit le code postal dans l'adresse (« 54000 Nancy »).
  def commune_de(ville, adresse)
    ville.presence || adresse.to_s[/\b\d{5}\s+([^,(]+)/, 1]&.strip
  end

  private

  def point_opportunite(o)
    {
      id: "o#{o.id}", titre: o.title.to_s.strip, categorie: o.category.to_s.downcase,
      debut: o.date_debut&.iso8601, fin: o.date_fin&.iso8601, horaire: o.schedule_text.presence,
      photo: photo_de(o), commune: commune_de(o.city, o.location),
      latitude: o.latitude.to_f, longitude: o.longitude.to_f, url: opportunity_path(o)
    }
  end

  def point_histoire(s)
    {
      id: "h#{s.id}", titre: s.title.to_s.strip, categorie: Categorie::HISTOIRES,
      debut: nil, fin: nil, horaire: nil,
      photo: photo_de(s), commune: commune_de(nil, s.location),
      latitude: s.latitude.to_f, longitude: s.longitude.to_f, url: story_path(s)
    }
  end

end
