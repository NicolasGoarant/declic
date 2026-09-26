# NOTES

## Règle éditoriale (fiches)
- **Opportunité** : invite à agir. Datée ou permanente (`schedule_text`). Bouton d'action `cta_button_text` / `cta_button_url`.
- **Belle Histoire** : récit inspirant, sans appel à l'action : aucun horaire, aucun bouton. Dit où trouver la personne (`venue_name`, `discover_url`), sa parole (`quote`, `quote_author`), la source (`source_name`, `source_url`, `source_published_on`).
- La maquette `declic-maquette-fiche-belle-histoire-v1.png` (Maison du Don) est une opportunité par son contenu : seule sa mise en page sert.

## Fait (branche `refonte-fiches`, sans push)
- Données : dates `starts_on`/`ends_on` + heures, `programme`, `audience`, `points_forts`, galerie `photos_order` (`GaleriePhotos`), complétude, pont des dates (`ConversionDates`).
- Admin : formulaires en partiels, galerie, colonne « Fiche ». `.env` chargé par dotenv-rails (dev/test).
- Vues publiques `opportunities#show` / `stories#show` refondues, layout `fiche` (accueil.css + fiche.css) : galerie (`galerie_controller`), favoris/partage/retour (`fiche_controller`, clé `declic:favoris`), mini-carte = `diorama` en mode `mini` (OSM hors emprise), OG/Twitter. `/labo/accueil?favoris=1` ouvre les favoris.
- `Opportunity.actuelles`, `#similaires` ; `Story#categorie_opportunite` (étiquettes), `#opportunites_proches`, `#autres_histoires`.
- Images de repli 1200 × 630 : `script/images_repli.py` (Pillow) → og_default, fallback-opportunity[-<catégorie>], fallback-story.
- Captures 390/1280 : `docs/captures/fiche-*-v1.png`.

## Tests
- `bin/rails test` : 82 verts. Système (8 verts) : `CHROME_NO_SANDBOX=1 CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome bin/rails test test/system` (pas de Chrome système ; le MCP Playwright ne trouve pas Chrome non plus).

## Reste à faire
- Contenus : photos Unsplash mortes en dev ; aucune fiche n'a de galerie, de programme, de public ni de logo ; histoires 4-8 avec `source_name` sans URL ; histoire #9 : location à Saint-Malo pour un atelier dans les Vosges ; histoire #8 plutôt une opportunité ; sections « Et moi, comment je peux avoir le Déclic ? » dans les corps (contraires à la règle).
- « Où rencontrer [prénom] » lit le 1er mot de `author_name` (pas de champ prénom dédié) : à confirmer.
- Lancer `declic:dates_rapport` en production ; puis supprimer start_date / end_date / highlights_*.
- Diorama (branche `refonte-accueil`) : zoom initial, bouquets, publication R2, licence Géonancy.
- `.bak` hors app/views à supprimer.

## Fichiers clés
- `app/views/{opportunities,stories}/show.html.erb`, `app/views/fiches/*`, `app/views/layouts/fiche.html.erb`, `app/helpers/fiches_helper.rb`, `app/assets/stylesheets/fiche.css`
- `app/javascript/controllers/{diorama,galerie,fiche}_controller.js` ; tests `test/system/fiches_test.rb`, `test/integration/fiches_partage_test.rb`
