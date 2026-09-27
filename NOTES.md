# NOTES
## Règle éditoriale (fiches)
- **Opportunité** : invite à agir. Datée ou permanente (`schedule_text`). Bouton d'action `cta_button_text` / `cta_button_url`.
- **Belle Histoire** : récit inspirant, sans appel à l'action : aucun horaire, aucun bouton. Dit où trouver la personne (`venue_name`, `discover_url`), sa parole (`quote`, `quote_author`), la source (`source_name`, `source_url`, `source_published_on`).
- La maquette `declic-maquette-fiche-belle-histoire-v1.png` (Maison du Don) est une opportunité par son contenu : seule sa mise en page sert.

## Fait (branche `refonte-fiches`, sans push)
- Données : dates `starts_on`/`ends_on` + heures, `programme`, `audience`, `points_forts`, galerie `photos_order` (`GaleriePhotos`), complétude, pont des dates (`ConversionDates`).
- Admin : formulaires en partiels, galerie, colonne « Fiche ». `.env` chargé par dotenv-rails (dev/test).
- Vues publiques `opportunities#show` / `stories#show` refondues, layout `fiche` (accueil.css + fiche.css) : galerie (`galerie_controller`), favoris/partage/retour (`fiche_controller`, clé `declic:favoris`), mini-carte = `diorama` en mode `mini` (OSM hors emprise), OG/Twitter. `/labo/accueil?favoris=1` ouvre les favoris.
- `Opportunity.actuelles`, `#similaires` ; `Story#categorie_opportunite` (étiquettes), `#opportunites_proches`, `#autres_histoires`. Images de repli 1200 × 630 : `script/images_repli.py` (Pillow).
- Histoire : « Où se rendre » + `venue_name` ; colonne `thematique` (admin) prioritaire pour les opportunités suggérées.
- Seeds (`db/seeds.rb`, `db/seeds/`) : 20 opportunités, 6 histoires dont 1 hors Métropole ; idempotents.
- Bords du diorama (`diorama/contour.js`) : contour `public/data/contour-metropole-v1.geojson` (geo.api.gouv.fr, EPCI 245400676, Admin Express IGN, Licence Ouverte 2.0, 256 pts) ; dalles hors contour non demandées, masque SVG flouté sur les dalles du bord, socle + ombre (volet Leaflet), table `--table-fond` ; maxBounds, minZoom au contour ; points hors contour non posés. Aussi mini-carte. Captures `docs/captures/diorama-bords-*-v1.png`. `versWGS84` corrigé (y en miroir).
- Calques (bouton au-dessus du zoom, partiels `accueil/calques/`) : fond Diorama/Plan OSM (bascule = carte recréée), maquette blanche, choix en localStorage (`diorama/preferences`), saveData → Plan. R2 : `masque-bati`, `propriete-toits-v1/8/` (pas de `dalles/`), `ambiances/{nom}-actuelle.json` ; masques lus avant la carte (sinon 404).
- Ambiances v2 (27/09) : moment × saison × météo cumulés + « Automatique » (soleil local `diorama/soleil`, mois, Open-Meteo caché 30 min, repli clair). Étalonnages dans `diorama/reglages.js` (seul fichier à retoucher). Absents de R2 : `masque-arbres` (automne en repli verts sombres), `lumieres-nuit` (nuit sans lumières, code prêt).
- Ambiances v4 (27/09) : particules `diorama/precipitations.js` refaites — 3 plans de profondeur (proche = plus gros/flou/rapide), densité proportionnelle à la surface de la carte (référence 1920×1080), tailles ×0,7 sur mobile, canevas mis à l'échelle du `devicePixelRatio`. Flou par plan **pré-rendu une fois en sprite** (`creerSprite`) : `ctx.filter` en direct coûtait ~78× plus cher en rendu logiciel. Neige : le contour du flocon doit rester NET (flouté après coup dans la 1ère version → invisible sur fond clair, corrigé en le traçant après avoir remis `ctx.filter="none"`) — vérifié en isolant le canevas des particules (`toDataURL`) sur fond clair et sombre, pas seulement à l'œil sur la capture pleine page (trop compressée pour juger). Pluie : assombrit légèrement la carte (uniform `pluieVoile`). Raccords entre dalles (DPR fractionnaire type 1,5/1,75, chaque canevas = calque GPU arrondi indépendamment) : 1 px de recouvrement CSS (`couches.js#comblerInterstices`). Captures `ambiances-v4-*-v1.png`.

## Tests
- `bin/rails test` : 88 verts. Système (19 verts, diorama servi par `test/support/tuiles_factices.rb`) : `CHROME_NO_SANDBOX=1 CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome bin/rails test test/system` (pas de Chrome système ; le MCP Playwright ne trouve pas Chrome non plus).

## Reste à faire
- Photos sources minuscules (salsa, serre, restos, stanislas1/2…) à remplacer ; `bachata.jpg` filigrane photographe (droits à confirmer).
- Contenus de production : `source_name` sans URL ; sections « Et moi, comment je peux avoir le Déclic ? » dans les corps (contraires à la règle).
- Base de dev : tables d'une autre branche (veille_*, sources…) ; ne pas régénérer schema.rb via db:migrate.
- Lancer `declic:dates_rapport` en production puis supprimer start_date / end_date / highlights_*. Licence Géonancy à confirmer.

## Fichiers clés
- `app/views/{opportunities,stories}/show.html.erb`, `app/views/fiches/*`, `app/views/layouts/fiche.html.erb`, `app/helpers/fiches_helper.rb`, `app/assets/stylesheets/fiche.css`
- `app/javascript/controllers/{diorama,galerie,fiche}_controller.js`, `app/javascript/diorama/*` ; tests `test/system/fiches_test.rb`, `test/integration/fiches_partage_test.rb` ; seeds `db/seeds.rb`, `db/seeds/`
