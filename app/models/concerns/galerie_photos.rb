# Galerie photos d'une fiche (has_many_attached :photos) : ordre, couverture, suppressions.
# L'ordre est stocké dans `photos_order` (ids d'attachments) ; les photos absentes de cette
# liste passent après, par id. La couverture est la première photo ; sans photos, on retombe
# sur l'ancienne image principale (`image`), qui reste lisible.
module GaleriePhotos
  extend ActiveSupport::Concern

  included do
    has_many_attached :photos
  end

  def photos_ordonnees
    ordre = Array(photos_order)
    photos.attachments.sort_by { |a| [ ordre.index(a.id) || ordre.size, a.id ] }
  end

  # Attachment de couverture : première photo de la galerie, sinon l'image principale.
  def couverture
    photos_ordonnees.first || (image.attachment if image.attached?)
  end

  def a_une_photo?
    photos.attached? || image.attached? || image_url.present?
  end

  # Applique le formulaire de galerie sur une fiche déjà enregistrée.
  #   nouvelles  : fichiers envoyés (ajoutés à la fin, sauf position explicite)
  #   supprimer  : ids d'attachments à supprimer
  #   positions  : { id_attachment => position } saisies dans le formulaire
  def appliquer_galerie(nouvelles: [], supprimer: [], positions: {})
    supprimer = Array(supprimer).map(&:to_i)
    photos.attachments.select { |a| supprimer.include?(a.id) }.each(&:purge)

    fichiers = Array(nouvelles).select { |f| f.respond_to?(:read) }
    avant = photos.attachments.map(&:id)
    photos.attach(fichiers) if fichiers.any?
    ajoutees = photos.attachments.reload.map(&:id) - avant

    positions = (positions || {}).to_h.transform_keys(&:to_i).transform_values { |v| v.to_s.strip.presence&.to_i }
    existantes = photos.attachments.map(&:id) - ajoutees
    rang = photos_ordonnees.map(&:id).each_with_index.to_h
    ordre = existantes.sort_by { |id| [ positions[id] || (rang[id] + 1), rang[id] ] } + ajoutees
    update_columns(photos_order: ordre)
  end
end
