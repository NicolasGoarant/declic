# NOTES

## Fait
- Branche `refonte-accueil` (partie de `export-diorama-dates`, PR #27) : `/labo/accueil`, la future home sur le diorama. La home actuelle et la route racine sont intactes.
  - Vue `labo/accueil` + partiels `app/views/accueil/`, layout `layouts/accueil`, CSS `accueil.css` (mobile ≤767, tablette, bureau ≥1024 avec panneau gauche de 380 px).
  - Contrôleur Stimulus `diorama_controller.js` : Leaflet et markercluster importés à la demande (jsdelivr `+esm`, `preload: false`), pins sur tige, grappes violettes, filtres, favoris localStorage, géolocalisation, volet `majVolet` porté de la v3.
  - Modules `app/javascript/diorama/` : couches (vrai, blanche), ambiance WebGL, soleil (mode auto), dates.
  - `DioramaTuiles` : base `DIORAMA_TILES_URL` (défaut tuiles-declic.mist-media.eu), sonde HEAD côté serveur mise en cache 10 min. La bascule et les ambiances ne s'affichent que si les fichiers sont publiés.
  - `Categorie` : source unique des 6 catégories ; marqueurs 96/192 px dans `app/assets/images/markers/`.
  - `Opportunity.date_iso` (ISO strict), partagée avec l'export ; `declic:dates_demo` (dev seulement, déjà lancée le 2026-09-26).
- Écran Carte plein écran (mobile/tablette < 1024 px) :
  - `.acc-ecran` = `100dvh - var(--tabbar-h)` ; `--tabbar-h` = 64 px + `env(safe-area-inset-bottom)` (une seule définition, dans `:root` de `accueil.css`, réutilisée par la tab bar, la carte et le corps de page). Leaflet recalcule sa taille via ResizeObserver + `orientationchange`.
  - Contrôles flottants, du haut vers le bas : logo « Déclic » (sans fond, halo blanc en text-shadow), recherche pleine largeur, six catégories sur une ligne (Belles Histoires en 6e, compteurs, filtre) ; fond blanc translucide + `backdrop-filter: blur`. Supprimés (2026-09-26) : puces Autour de moi / Aujourd'hui / Cette semaine / Filtres, sélecteur Grand Nancy, recentrage, cloche et profil du haut, et le JS associé (géolocalisation, filtres temporels, rayon). Le volet est toujours « Au centre de la vue », trié par distance au centre.
  - Vue initiale : constantes `CENTRE_INITIAL` (place Stanislas 48.6936 N, 6.1833 E, via `diorama_projection.js`) et `ZOOM_INITIAL` en tête de `diorama_controller.js`. `?debug_vue=1` affiche centre lat/lon + zoom en direct (`versWGS84`, inverse au sol). « Voir tout » recadre encore sur tous les pins (`cadrer`).
  - Accroche (h1) : masquée visuellement hors bureau (reste dans le DOM pour les lecteurs d'écran), affichée dans le panneau gauche ≥ 1024 px. Choix le plus simple : aucun autre écran « Explorer » n'existe dans cette page.
  - Bottom sheet `sheet_controller.js` (partiel `_volet`) : repliée = poignée de 56 px (`--poignee-h`) ; dépliée = 55 dvh (`--sheet-h`). Déplacement par `transform: translateY` (250 ms ease-out), jamais `height`. Tap sur la poignée, glisser (seuil 60 px : > 60 haut = ouvre, > 60 bas = ferme, sinon retour), Échap, tap sur la carte ou « Voir tout » = replie. Focus sur la 1re fiche à l'ouverture ; panneau `inert` tant qu'elle est repliée. La poignée affiche titre, « n lieux » (cadrage courant, mis à jour à chaque déplacement/zoom) et chevron. Sur bureau : panneau fixe, sans sheet.
  - Sheet dépliée : zoom/recentrage s'effacent, l'attribution monte avec elle.
  - Tab bar : Carte · Explorer · [+] · Favoris · Profil, 5 cellules égales (≥ 44 px). Le « + » (56 px, dépasse de 16 px, sans overflow hidden) est le lien `new_opportunity_path` (aria-label « Proposer »). Onglet courant : Carte tant que Favoris n'est pas actif (`diorama#majOnglets`), Favoris actif = `aria-pressed`, violet + gras.
  - Tests système : `test/system/accueil_test.rb` (sheet repliée puis ouverte, tab bar 5 items avec « + » en 3e). Sans Chrome installé : `CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome CHROME_NO_SANDBOX=1 bin/rails test test/system`.
- Antérieur (PR #27) : export diorama, `/labo/diorama`, `diorama_projection.js`, carte de la home dans `shared/_map`.

## Reste à faire
- Zoom initial (6) provisoire : `docs/maquettes/declic-vue-initiale-stanislas-v1.png` absente du dépôt ; comparer et ajuster `ZOOM_INITIAL` avec `?debug_vue=1`.
- Publier sur R2 `masque-bati/`, `toits-v1-propriete/` (chacun avec un `manifeste.json`) et `ambiances/{nom}-actuelle.json` : bascule et ambiances apparaîtront seules.
- Licence Géonancy : le manifeste dit encore « local seulement ».
- Sur mobile, « Des histoires qui inspirent », témoignages et presse restent sous l'écran Carte (scroll de page, atteignable seulement en glissant hors de la carte). À décider : les mettre dans la sheet ou sur l'écran Explorer.
- Test préexistant en échec : `pages_controller_test` (route `pages_home_url` inexistante).
- Images mortes en base dev (Unsplash bloquées ORB) : la fiche retombe sur le pictogramme.
- Cloche et profil ne sont que des emplacements ; témoignages dupliqués depuis la home (à retirer de là-bas à la bascule).
- Altitude des marqueurs (z = z_ref) ; MJC Desforges (id 104) à vérifier en prod ; `home.html.erb.bak`.
- Vérifier à la main le prompt de géolocalisation réel (Chrome du MCP Playwright absent : vérifs via `~/.cache/ms-playwright/chromium-1243`).

## Fichiers clés
- `app/views/labo/accueil.html.erb`, `app/views/accueil/*`, `app/assets/stylesheets/accueil.css`
- `app/javascript/controllers/diorama_controller.js`, `app/javascript/diorama/*`
- `app/models/diorama_tuiles.rb`, `app/models/categorie.rb`, `app/helpers/accueil_helper.rb`
