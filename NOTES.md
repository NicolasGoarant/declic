# NOTES

## Fait
- Export diorama : tâche `declic:export_diorama` (opportunités publiées et à venir en JSON public, hors dépôt), dates et image corrigées.
- Géocodage restreint à la zone de Nancy.
- Compteurs publics calculés depuis la base ; articles de presse fictifs retirés.
- Carte de la home extraite dans le partial `app/views/shared/_map.html.erb` (HTML, CSS, JS Leaflet, popups, géolocalisation).
  - Filtre par catégorie : `window._declicFilter(cat)`, appelé par les chips/select de la home.
  - Une seule carte par page (`id="map"`, globals `window._declic*`).
  - Option `locate: false` pour masquer le bouton « Me localiser ».
- Corrigé : `_declicButton` dans `stopFollow` ; Leaflet n'est plus rechargé par le partial (markercluster en `defer`, après le Leaflet du layout).

## Reste à faire
- Décider du sort de `app/views/pages/home.html.erb.bak` (ancienne copie, non rendue).
- Fichiers non suivis à trier : `app/assets/images/markers/`, `docs/`.

## Fichiers clés
- `app/views/pages/home.html.erb` : home, sticky de la carte, filtres, compteurs.
- `app/views/shared/_map.html.erb` : carte réutilisable.
- `app/views/layouts/application.html.erb` : charge Leaflet (l.40-41).
