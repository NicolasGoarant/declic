# frozen_string_literal: true

# Badges et listes du classement dans l'admin (galerie, écran d'un candidat). Couleurs et libellés viennent de
# Categorie : ce sont ceux du site public.
module GalerieHelper
  # Catégories d'opportunités (sans « Belles Histoires ») pour un <select> : [libellé, clé].
  def options_categories_opportunite
    Categorie::TOUTES.reject { |c| c.cle == Categorie::HISTOIRES }.map { |c| [ c.libelle, c.cle ] }
  end

  def options_types_classement
    Galerie::TYPES.map { |cle, libelle| [ libelle, cle ] }
  end

  # Badge de catégorie aux couleurs du site public. Clé absente de Categorie (ancienne taxonomie) : badge gris qui
  # le dit, pour qu'elle soit reclassée plutôt que passée sous silence.
  def pastille_categorie(cle)
    return if cle.blank?

    categorie = Categorie.trouver(cle)
    return tag.span("#{cle} (ancienne)", class: "badge no", title: "Catégorie qui n'existe plus : à reclasser") unless categorie

    tag.span(categorie.libelle, class: "badge cat", style: "background:#{categorie.couleur};color:#{texte_lisible_sur(categorie.couleur)}")
  end

  # Pastille de statut : couleur + pictogramme + libellé (le sens ne repose jamais sur la couleur seule).
  STATUTS_PASTILLE = {
    "non_trie"   => [ "À traiter", "●", "#FEF3C7", "#7C2D12" ],
    "propose"    => [ "Proposée", "◆", "#E0E7FF", "#312E81" ],
    "a_verifier" => [ "À vérifier", "!", "#FFEDD5", "#7C2D12" ],
    "en_ligne"   => [ "En ligne", "✓", "#DCFCE7", "#14532D" ],
    "retire"     => [ "Retirée", "–", "#E2E8F0", "#1E293B" ],
    "ecarte"     => [ "Écartée", "✕", "#E2E8F0", "#1E293B" ]
  }.freeze

  def pastille_statut(statut)
    libelle, glyphe, fond, encre = STATUTS_PASTILLE.fetch(statut)
    tag.span(class: "pastille statut s-#{statut}", style: "background:#{fond};color:#{encre}") do
      safe_join([ tag.span(glyphe, class: "glyphe", "aria-hidden": "true"), libelle ])
    end
  end

  # Compteurs du bandeau : un par statut réel, dans l'ordre de travail (À traiter → Retirées du site).
  COMPTEURS = [
    [ "non_trie", "À traiter", "#B45309" ], [ "propose", "Proposées", "#4338CA" ], [ "a_verifier", "À vérifier", "#C2410C" ],
    [ "en_ligne", "En ligne", "#15803D" ], [ "ecarte", "Écartées", "#475569" ], [ "retire", "Retirées du site", "#475569" ]
  ].freeze

  # « 1 - 48 sur 279 ».
  def plage_affichee(page, total, par_page)
    "#{(page - 1) * par_page + 1} - #{[ page * par_page, total ].min} sur #{total}"
  end

  # Fiabilité en français, pour la pastille de la carte.
  def libelle_fiabilite(valeur) = Galerie::FIABILITES.fetch(valeur.to_s, valeur.to_s.humanize).downcase

  private

  # Noir ou blanc selon la luminance du fond (formule WCAG simplifiée).
  def texte_lisible_sur(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) }
    (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? "#1f2937" : "#ffffff"
  end
end
