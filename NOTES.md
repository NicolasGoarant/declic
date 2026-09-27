# NOTES
## Règle éditoriale (fiches)
- **Opportunité** : invite à agir. Datée ou permanente (`schedule_text`). Bouton d'action `cta_button_text` / `cta_button_url`.
- **Belle Histoire** : récit inspirant, sans appel à l'action : aucun horaire, aucun bouton. Dit où trouver la personne (`venue_name`, `discover_url`), sa parole (`quote`, `quote_author`), la source (`source_name`, `source_url`, `source_published_on`).

## Fait (branche `refonte-fiches`, sans push)
- Fiches publiques (`opportunities`/`stories#show`), diorama (bords, calques, styles Réaliste/Jeu vidéo, ambiances, Pins v2), « Pourquoi Déclic ? » : détail dans l'historique git (messages de commit).
- Dézoom (28/09) : repli générique sur le style Réaliste (`STYLE_REPLI`, `styleDalle`) sous le `niveau_min` d'un style partiel (ex. `jeu-video-v1`, dalles seulement à partir du niveau 6) ; maxZoom recadré à 8. Reste : publier `jeu-video-v1` niveaux 0-5 sur R2 (cosmétique).
- **Opportunités / Belles Histoires** (28/09, `/labo/opportunites`, `/labo/belles-histoires`, `labo_helper.rb`) : navbar du labo mise à jour (« Opportunités », pointe vers ces pages neuves ; `/opportunities`/`/stories` publics inchangés, **penser à une redirection le jour où le public bascule dessus**). Filtre par les 5 vraies catégories (`Opportunity::CATEGORIES`), pas celles des maquettes (8 pour Opportunités, thématiques fictives pour Belles Histoires). Carte = `diorama_controller` compact (nouveau : `localiser()`/géoloc, pastille « Toutes », `icone_categorie` pour dissocier filtre et pictogramme du pin). Grille de cartes + recherche/tri/rayon : nouveau `explorateur_controller.js`, indépendant, synchronisé avec la carte par les mêmes boutons de catégorie et l'événement `diorama:localise`. « Les plus populaires » omis (aucune métrique de popularité en base).
- **En-têtes haute définition** (27/09) : photos fournies intégrées (`app/assets/images/entetes/*.webp`, q80, 2000/1000 px + recadré mobile 750×500), sources PNG (~2 Mo) hors build dans `docs/maquettes/entetes-sources/`. Desktop : photo pleine largeur en fond, texte sur sa zone claire (`.lb-hero-centre` pour Opportunités = centré, Belles Histoires = à gauche). Mobile : photo recadrée sur le sujet au-dessus du texte (pas en fond, plus lisible).

## Tests
- `bin/rails test` : 105 verts (+ helpers/labo, contrôleurs labo_opportunites/labo_belles_histoires). Système (21 verts) : `CHROME_NO_SANDBOX=1 CHROME_BIN=~/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome bin/rails test test/system` (pas de Chrome système ; capture via `selenium-webdriver`, même binaire).

## Reste à faire
- Champs à surveiller en prod (100 % remplis sur les seeds actuels, volumétrie faible) : `Story#thematique`/`quote`/`source_published_on`, photos.
- Photos sources minuscules à remplacer ; `source_name` sans URL ; sections « Et moi... » dans les corps (contraires à la règle éditoriale).
- Base de dev : tables d'une autre branche ; ne pas régénérer schema.rb via db:migrate.

## Fichiers clés
- `app/views/labo/{opportunites,belles_histoires}.html.erb`, `_filtre_categories.html.erb`, `app/helpers/labo_helper.rb`, `app/javascript/controllers/explorateur_controller.js`, `app/assets/stylesheets/labo_pages.css`
- `app/views/{opportunities,stories}/show.html.erb`, `app/views/layouts/fiche.html.erb`, `app/assets/stylesheets/{fiche,accueil}.css`, `app/javascript/controllers/{diorama,galerie,fiche}_controller.js`, `app/javascript/diorama/*` ; seeds `db/seeds.rb`, `db/seeds/`
