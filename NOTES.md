# NOTES

## Fait
- Branche `refonte-accueil` (partie de `export-diorama-dates`, PR #27) : `/labo/accueil`, la future home sur le diorama. La home actuelle et la route racine sont intactes.
  - Vue `labo/accueil` + partiels `app/views/accueil/`, layout `layouts/accueil`, CSS `accueil.css` (mobile ≤767, tablette, bureau ≥1024 avec panneau gauche de 380 px).
  - Contrôleur Stimulus `diorama_controller.js` : Leaflet et markercluster importés à la demande (jsdelivr `+esm`, `preload: false`), pins sur tige, grappes violettes, filtres, favoris localStorage, géolocalisation, volet `majVolet` porté de la v3.
  - Modules `app/javascript/diorama/` : couches (vrai, blanche), ambiance WebGL, soleil (mode auto), dates.
  - `DioramaTuiles` : base `DIORAMA_TILES_URL` (défaut tuiles-declic.mist-media.eu), sonde HEAD côté serveur mise en cache 10 min. La bascule et les ambiances ne s'affichent que si les fichiers sont publiés.
  - `Categorie` : source unique des 6 catégories ; marqueurs 96/192 px dans `app/assets/images/markers/`.
  - `Opportunity.date_iso` (ISO strict), partagée avec l'export ; `declic:dates_demo` (dev seulement, déjà lancée le 2026-09-26).
- Antérieur (PR #27) : export diorama, `/labo/diorama`, `diorama_projection.js`, carte de la home dans `shared/_map`.

## Reste à faire
- Publier sur R2 `masque-bati/`, `toits-v1-propriete/` (chacun avec un `manifeste.json`) et `ambiances/{nom}-actuelle.json` : bascule et ambiances apparaîtront seules.
- Licence Géonancy : le manifeste dit encore « local seulement ».
- Test préexistant en échec : `pages_controller_test` (route `pages_home_url` inexistante).
- Images mortes en base dev (Unsplash bloquées ORB) : la fiche retombe sur le pictogramme.
- Cloche et profil ne sont que des emplacements ; témoignages dupliqués depuis la home (à retirer de là-bas à la bascule).
- Altitude des marqueurs (z = z_ref) ; MJC Desforges (id 104) à vérifier en prod ; `home.html.erb.bak`.
- Vérifier à la main le prompt de géolocalisation réel (Chrome du MCP Playwright absent : vérifs via `~/.cache/ms-playwright/chromium-1243`).

## Fichiers clés
- `app/views/labo/accueil.html.erb`, `app/views/accueil/*`, `app/assets/stylesheets/accueil.css`
- `app/javascript/controllers/diorama_controller.js`, `app/javascript/diorama/*`
- `app/models/diorama_tuiles.rb`, `app/models/categorie.rb`, `app/helpers/accueil_helper.rb`
