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
- Ambiances v2-v7d (27/09) : moment × saison × météo cumulés + « Automatique » (soleil local, Open-Meteo caché 30 min, `diorama/reglages.js`) ; particules `precipitations.js`, lampadaires (`diorama/lampadaires.js`) ; Nuit v7d (`MOMENTS.nuit`, cibles HSV `NUIT_CIBLES`, ombres `giroYZ` sans frange, clarté en lift additif plafonné) ; saturation des ombres encore sous la cible. Captures `nuit-v7b-*-v1.png`.
- **Pourquoi Déclic ?** (27/09, `pages#philosophie`, layout fiche) : maquette `docs/maquettes/declic-maquette-pourquoi-v1.png` ; chiffres en cache 10 min ; collage = photo d'une vraie fiche par catégorie sinon repli `app/assets/images/pourquoi/*.webp` ; carte SVG du contour (`PourquoiCarte`), pins écartés sur de vraies opportunités ; barre haute : 2 boutons sur cette page ; « © année Déclic » dans `accueil/_pied`. Captures `pourquoi-v1-*-v1.png`.
- **Style du diorama** (27/09, `/labo/accueil`) : rubrique « Style » du panneau Calques, Réaliste (`toits-v1`) / Jeu vidéo (`jeu-video-v1`, par défaut), `DioramaTuiles::STYLES` (un style masqué si son manifeste manque), mémorisé (`declic:style`). Masque du bâti/propriété/arbres/lampadaires partagés entre styles (géométrie, pas rendu) ; bascule = juste la couche de fond recalculée (`diorama_controller#changerStyle`), carte/marqueurs/ambiance inchangés, `this.couches` vidé. Captures `styles-*-v1.png` (+ recadrages ×2 place Stanislas) : overlays (arbres automne, neige, lampadaires nuit) bien alignés aux deux styles. `masque-routes`/`masque-facades` non publiés sur R2.
## Tests
- `bin/rails test` : 91 verts. Système (21 verts, diorama servi par `test/support/tuiles_factices.rb`, les 2 styles publiés) : `CHROME_NO_SANDBOX=1 CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome bin/rails test test/system` (pas de Chrome système ; le MCP Playwright ne trouve pas Chrome non plus — capture via `selenium-webdriver` en Ruby, même binaire).

## Reste à faire
- Photos sources minuscules (salsa, serre, restos, Stan2 = héros/OG « Pourquoi » en 275 px) à remplacer ; `bachata.jpg` filigrane (droits). Doublon `nicolas_goarant(2).png` à supprimer.
- Contenus de production : `source_name` sans URL ; sections « Et moi, comment je peux avoir le Déclic ? » dans les corps (contraires à la règle).
- Base de dev : tables d'une autre branche (veille_*, sources…) ; ne pas régénérer schema.rb via db:migrate.
- Lancer `declic:dates_rapport` en production puis supprimer start_date / end_date / highlights_*. Licence Géonancy à confirmer.

## Fichiers clés
- `app/views/{opportunities,stories}/show.html.erb`, `app/views/fiches/*`, `app/views/layouts/fiche.html.erb`, `app/helpers/fiches_helper.rb`, `app/assets/stylesheets/fiche.css`
- `app/javascript/controllers/{diorama,galerie,fiche}_controller.js`, `app/javascript/diorama/*` ; tests `test/system/fiches_test.rb`, `test/integration/fiches_partage_test.rb` ; seeds `db/seeds.rb`, `db/seeds/`
