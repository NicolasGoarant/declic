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

  private

  # Noir ou blanc selon la luminance du fond (formule WCAG simplifiée).
  def texte_lisible_sur(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) }
    (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? "#1f2937" : "#ffffff"
  end
end
