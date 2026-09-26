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
- Page de test `/labo/diorama` (viewer de la mosaïque toits-v1, hors navigation) + module `app/javascript/diorama_projection.js` : WGS84/Lambert-93 → pixel de mosaïque, portage de `~/Documents/nancy-3d/projection.js` (identique au pixel près).
  - Affiche les vraies opportunités (`/api/v1/opportunities`), cercles colorés par catégorie, popup au clic (même fiche que Leaflet + extrait de description). Compteur « n/N dans le secteur couvert » dans le HUD.
  - Secteur couvert = dalle listée au niveau 8 du manifeste (pas le simple rectangle) ; hors secteur = exclu en silence. Actuellement 17/18 (reste : Landremont).
  - Sans MNS : z = z_ref (231,17 m) ; ~1,73 px de mosaïque par mètre d'écart → marqueurs ~35-45 px trop hauts en ville basse.
  - Vérifié en Chromium headless (`~/.cache/ms-playwright/chromium-1243`, piloté via CDP) ; le Chrome du MCP Playwright reste absent.
- MJC Desforges (id 104) : coordonnées corrigées en base de DEV seulement (était dans le Loiret) ; à refaire en prod si la fiche y existe.

## Reste à faire
- Décider d'une correction d'altitude des marqueurs (MNS ou altitude par point).
- Vérifier/corriger MJC Desforges (id 104) en production.
- Décider du sort de `app/views/pages/home.html.erb.bak` (ancienne copie, non rendue).
- Fichiers non suivis à trier : `app/assets/images/markers/`, `docs/`.

## Fichiers clés
- `app/views/pages/home.html.erb` : home, sticky de la carte, filtres, compteurs.
- `app/views/shared/_map.html.erb` : carte réutilisable.
- `app/views/layouts/application.html.erb` : charge Leaflet (l.40-41).
