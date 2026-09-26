# NOTES

## Fait
- Branche `refonte-accueil` (partie de `export-diorama-dates`, PR #27) : `/labo/accueil`, future home sur le diorama. Home actuelle et route racine intactes.
  - Vue `labo/accueil` + partiels `app/views/accueil/`, layout `layouts/accueil`, CSS `accueil.css` (mobile, tablette ≥ 768, bureau ≥ 1024 avec panneau gauche de 380 px).
  - `diorama_controller.js` : Leaflet importé à la demande (jsdelivr `+esm`, `preload: false`), favoris localStorage, volet « Au centre de la vue » trié par distance au centre. `DioramaTuiles` sonde les tuiles publiées ; `Categorie` = source unique des 6 catégories ; `declic:dates_demo` (dev) déjà lancée.
- Écran Carte mobile (< 1024 px) : `.acc-ecran` = `100dvh - var(--tabbar-h)` (64 px + safe area). En haut : le seul logo « Déclic » (sans fond, halo blanc). Accroche h1 masquée hors bureau.
  - Légende des 6 catégories (compteurs, filtre) : dans le volet, au-dessus de la poignée (`--legende-h` 62 px, 84 px tablette). Choix : elle MONTE avec le volet ouvert. Zoom +/- et (i) décalés au-dessus. Bureau : en tête du panneau gauche.
  - Bottom sheet `sheet_controller.js` : poignée 56 px (`--poignee-h`), ouverte 55 dvh (`--sheet-h`), `translateY` 250 ms, seuil de glissement 60 px, Échap, tap carte. Émet `sheet:ouverte` (ferme la popup).
  - Tab bar : Carte · Explorer · [+] Proposer · Favoris · Profil.
- Pins : `diorama/bouquets.js` remplace Leaflet.markercluster (supprimé : import, importmap, CSS). Pieds à < 28 px à l'écran → bouquet : pied commun au barycentre, tiges en éventail -45°…+45°, longueurs alternées, 6 fleurs max + « +n » (zoome sur le groupe). Recalcul à chaque `zoomend` et filtre (`dessinerPins`).
  - Popup au clic (pin ou fleur) : photo ou icône, catégorie, titre, date, commune, « Voir la fiche » / « Lire l'histoire ». Autopan avec `marges()` (logo en haut, légende et volet en bas). Fermeture : tap carte, Échap, ouverture du volet.
  - Vue initiale : `CENTRE_INITIAL` (place Stanislas) et `ZOOM_INITIAL` (6) ; `?debug_vue=1` affiche centre et zoom.
- Tests système `test/system/accueil_test.rb` (sans tuiles : sheet, tab bar, légende). Sans Chrome : `CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome CHROME_NO_SANDBOX=1 bin/rails test test/system`.

## Reste à faire
- Zoom initial provisoire : `docs/maquettes/declic-vue-initiale-stanislas-v1.png` absente ; ajuster `ZOOM_INITIAL` avec `?debug_vue=1`.
- 4 paires d'opportunités ont des coordonnées identiques en base : elles restent en bouquet de 2 au zoom max.
- Publier sur R2 `masque-bati/`, `toits-v1-propriete/`, `ambiances/` ; licence Géonancy (« local seulement »).
- Sur mobile, histoires, témoignages et presse restent sous l'écran Carte : les mettre dans la sheet ou sur Explorer ?
- Préexistant : `pages_controller_test` en échec (`pages_home_url`) ; images Unsplash mortes en dev ; `home.html.erb.bak`.
- Témoignages dupliqués depuis la home ; altitude des marqueurs (z = z_ref) ; MJC Desforges (id 104) à vérifier en prod.

## Fichiers clés
- `app/views/labo/accueil.html.erb`, `app/views/accueil/*`, `app/assets/stylesheets/accueil.css`
- `app/javascript/controllers/{diorama,sheet}_controller.js`, `app/javascript/diorama/*` (bouquets, couches, dates…)
- `app/models/diorama_tuiles.rb`, `app/models/categorie.rb`, `app/helpers/accueil_helper.rb`
