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
    carte: [ "M14.1 5.55a2 2 0 0 0 1.8 0l3.65-1.83A1 1 0 0 1 21 4.62v12.76a1 1 0 0 1-.55.9l-4.55 2.27a2 2 0 0 1-1.8 0l-4.2-2.1a2 2 0 0 0-1.8 0l-3.65 1.83A1 1 0 0 1 3 19.38V6.62a1 1 0 0 1 .55-.9L8.1 3.45a2 2 0 0 1 1.8 0z", "M15 5.76v15", "M9 3.24v15" ],
    chercher: [ { circle: { cx: 11, cy: 11, r: 8 } }, "m21 21-4.3-4.3" ],
    coeur: [ "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" ],
    proposer: [ { circle: { cx: 12, cy: 12, r: 10 } }, "M8 12h8", "M12 8v8" ],
    plus: [ "M5 12h14", "M12 5v14" ],
    moins: [ "M5 12h14" ],
    profil: [ "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2", { circle: { cx: 12, cy: 7, r: 4 } } ],
    cloche: [ "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9", "M10.3 21a1.94 1.94 0 0 0 3.4 0" ],
    lieu: [ "M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z", { circle: { cx: 12, cy: 10, r: 3 } } ],
    chevron: [ "m6 9 6 6 6-6" ],
    viseur: [ { circle: { cx: 12, cy: 12, r: 7 } }, { circle: { cx: 12, cy: 12, r: 2.5 } }, "M12 2v3", "M12 19v3", "M2 12h3", "M19 12h3" ],
    calendrier: [ { rect: { x: 3, y: 4, width: 18, height: 18, rx: 2 } }, "M16 2v4", "M8 2v4", "M3 10h18" ],
    horloge: [ { circle: { cx: 12, cy: 12, r: 10 } }, "M12 6v6l4 2" ],
    reglages: [ "M21 4h-7", "M10 4H3", "M21 12h-9", "M8 12H3", "M21 20h-5", "M12 20H3", "M14 2v4", "M8 10v4", "M16 18v4" ],
    recentrer: [ "M3 11l19-9-9 19-2-8-8-2z" ],
    signet: [ "m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z" ],
    fleche: [ "M5 12h14", "m12 5 7 7-7 7" ],
    distance: [ "m18 8 4 4-4 4", "M2 12h20", "m6 8-4 4 4 4" ],
    # Fiches Opportunité / Belle Histoire
    retour: [ "m12 19-7-7 7-7", "M19 12H5" ],
    precedent: [ "m15 18-6-6 6-6" ],
    suivant: [ "m9 18 6-6-6-6" ],
    partager: [ { circle: { cx: 18, cy: 5, r: 3 } }, { circle: { cx: 6, cy: 12, r: 3 } }, { circle: { cx: 18, cy: 19, r: 3 } }, "m8.59 13.51 6.83 3.98", "m15.41 6.51-6.82 3.98" ],
    lien: [ "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71", "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" ],
    externe: [ "M15 3h6v6", "M10 14 21 3", "M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" ],
    ampoule: [ "M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5", "M9 18h6", "M10 22h4" ],
    groupe: [ "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", { circle: { cx: 9, cy: 7, r: 4 } }, "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75" ],
    programme: [ { rect: { x: 8, y: 2, width: 8, height: 4, rx: 1 } }, "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2", "M12 11h4", "M12 16h4", "M8 11h.01", "M8 16h.01" ],
    livre: [ "M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z", "M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" ],
    journal: [ "M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2", "M18 14h-8", "M15 18h-5", "M10 6h8v4h-8V6Z" ],
    etoile: [ "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z" ],
    courriel: [ { rect: { x: 2, y: 4, width: 20, height: 16, rx: 2 } }, "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" ],
    termine: [ { circle: { cx: 12, cy: 12, r: 10 } }, "m9 12 2 2 4-4" ]
  }.freeze

  # Logos des réseaux (tracés Simple Icons, CC0), pleins, couleur du texte.
  RESEAUX = {
    facebook: "M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.628 3.874 10.35 9.101 11.647Z",
    x: "M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z",
    linkedin: "M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v13.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"
  }.freeze

  def logo_reseau(nom, taille: 18)
    tag.svg(tag.path(d: RESEAUX.fetch(nom)), width: taille, height: taille, viewBox: "0 0 24 24",
            fill: "currentColor", "aria-hidden" => "true", focusable: "false")
  end

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
      debut: o.starts_on&.iso8601, fin: o.ends_on&.iso8601, horaire: o.schedule_text.presence,
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
