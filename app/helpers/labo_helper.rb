# Données JSON des pages Opportunités et Belles Histoires (/labo/opportunites, /labo/belles-histoires) :
# une carte diorama (pins) + une grille de cartes, tenues à jour ensemble par explorateur_controller.js.
# Champ par champ, réutilise ce qui existe déjà (accueil_helper, Opportunity#date_affichee...) plutôt
# que de reformater les dates ou les lieux une deuxième fois.
module LaboHelper
  # Les 5 catégories réelles (Opportunity::CATEGORIES), sans la pseudo-catégorie « histoires » qui
  # ne sert qu'au diorama de /labo/accueil : le filtre de ces deux pages n'en a pas besoin.
  def categories_reelles
    Categorie::TOUTES.reject { |c| c.cle == Categorie::HISTOIRES }
  end

  def opportunite_pour_carte(o)
    cat = Categorie.trouver(o.category)
    {
      id: "o#{o.id}", titre: o.title, categorie: o.category,
      categorie_libelle: cat&.libelle, categorie_couleur: cat&.couleur,
      categorie_icone: cat && image_path("#{cat.icone}.png"), categorie_icone2x: cat && image_path("#{cat.icone}@2x.png"),
      commune: commune_de(o.city, o.location), latitude: o.latitude.to_f, longitude: o.longitude.to_f,
      debut: o.starts_on&.iso8601, fin: o.ends_on&.iso8601,
      date_affichee: o.date_affichee || "Ouvert toute l'année", horaire: o.horaire_affiche,
      extrait: excerpt_texte(o.description), photo: photo_de(o),
      url: opportunity_path(o), cree_le: o.created_at.iso8601
    }
  end

  def histoire_pour_carte(s)
    cat = Categorie.trouver(s.categorie_opportunite)
    {
      id: "s#{s.id}", titre: s.title, categorie: s.categorie_opportunite,
      # Le pin montre toujours l'étincelle « Belles Histoires » (comme /labo/accueil), même si le
      # filtre porte sur la thématique réelle (diorama_controller#iconePin).
      icone_categorie: Categorie::HISTOIRES,
      categorie_libelle: cat&.libelle, categorie_couleur: cat&.couleur,
      categorie_icone: cat && image_path("#{cat.icone}.png"), categorie_icone2x: cat && image_path("#{cat.icone}@2x.png"),
      commune: commune_de(s.city, s.location), latitude: s.latitude.to_f, longitude: s.longitude.to_f,
      citation: s.quote.presence, date_affichee: mois_annee(s.source_published_on),
      photo: photo_de(s), url: story_path(s), cree_le: (s.source_published_on || s.created_at).to_time.iso8601
    }
  end

  def mois_annee(date)
    return nil unless date
    "#{Opportunity::MOIS[date.month - 1].capitalize} #{date.year}"
  end

  # escape: false — le texte part en JSON (data-*-points-value) et revient posé en JS par
  # .textContent (jamais interprété comme HTML) : pas besoin d'échapper, et ça éviterait un
  # « &#39; » affiché tel quel à l'écran (truncate échappe par défaut).
  def excerpt_texte(texte, longueur: 140)
    truncate(texte.to_s.squish, length: longueur, separator: " ", escape: false)
  end
end
