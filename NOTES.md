# NOTES

## Règle éditoriale (fiches)
- **Opportunité** : le texte invite à agir (participer, s'inscrire, donner, se former). Datée ou permanente (« Ouvert toute l'année, sur rendez-vous » va dans `schedule_text`). Porte un bouton d'action (`cta_button_text` / `cta_button_url`).
- **Belle Histoire** : récit inspirant du parcours de quelqu'un, sans appel à l'action : aucun horaire, aucun bouton personnalisé. Dit où trouver la personne (`venue_name`, `discover_url`), ce qu'elle dit (`quote`, `quote_author`), d'où vient le récit (`source_name`, `source_url`, `source_published_on`).
- La maquette `declic-maquette-fiche-belle-histoire-v1.png` (Maison du Don) est une opportunité par son contenu : seule sa mise en page sert de modèle.

## Fait (branche `refonte-fiches`, chantier données)
- Opportunity : `audience`, `programme` (json), `organization_logo`, `starts_on`/`ends_on` (date), `start_time`/`end_time` (time). Affichage : `date_affichee`, `horaire_affiche`, `permanente?`, `a_venir?` (pas encore terminée), `passee?`, `programme_liste`. `date_debut`/`date_fin` préfèrent `starts_on`/`ends_on`.
- Reprise des dates : `ConversionDates` (migration + rake `declic:dates_rapport`, lecture seule). starts_at à minuit UTC pile = date sans heure. Pont `before_save` start_date/end_date ISO -> starts_on/ends_on.
- Story : `venue_name`, `discover_url`, `quote_author`, `points_forts` (json, 3 max, `PointsForts`), `source_published_on` ; highlights_items repris dans points_forts.
- Sécurité : seeds refusés en production sans `SEED_ALLOW_DESTROY=oui` ; admin en 403 si ADMIN_USERNAME / ADMIN_PASSWORD absent ou vide (développement compris).
- `pages_controller_test` réparé (`root_url`). Suite verte.

- Chantier admin : formulaires découpés en partiels (`admin/{opportunities,stories}/form/*`, styles communs `admin/shared/`), nouveaux champs autorisés. Le formulaire écrit `starts_on`/`ends_on` ; pont inverse `before_save` (`synchroniser_dates`) vers `start_date`/`end_date` ISO.
  - Galerie photos (`GaleriePhotos`, colonne `photos_order` = ids d'attachments, 1re = couverture ; `couverture` retombe sur `image`). Formulaire : `galerie[nouvelles|supprimer|positions]`.
  - Complétude (`FicheCompletude`, colonne « Fiche » triable `?tri=fiche&sens=`). Points forts : 3 blocs fixes (`points_forts_saisie`, icônes dans `PointsForts::ICONES`). Programme : `programme_texte`.
  - Recherche admin via `arel_table[:title].matches` ; route `geocode_missing` des opportunités ; `.bak` de app/views supprimés. Story : `location` exigée à la création seulement.
  - Contrôle manuel : le serveur 3003 n'a pas ADMIN_* dans son environnement (403) ; lancer avec `set -a; . ./.env`.

## Reste à faire
- Refonte des vues publiques fiches Opportunité / Belle Histoire (maquettes `docs/maquettes/declic-maquette-fiche-*-v1.png`) : lire `couverture`, `photos_ordonnees`, `programme_liste`, `points_forts_liste`, `date_affichee`, `horaire_affiche`.
- Lancer `declic:dates_rapport` en production avant/après la migration ; version de transition puis suppression de start_date / end_date / highlights_*.
- Histoire #8 (jardin participatif) : plutôt une opportunité. Sections « Et moi, comment je peux avoir le Déclic ? » = appels à l'action, contraires à la règle. #9 : location à Saint-Malo pour un atelier dans les Vosges.
- Diorama (branche `refonte-accueil`) : zoom initial, bouquets de coordonnées identiques, publication R2, licence Géonancy.
- Préexistant : images Unsplash mortes en dev ; `.bak` hors app/views (application.css.bak, stories_helper.rb.bak, credentials.yml.enc.bak).

## Fichiers clés
- `app/models/{opportunity,story,conversion_dates,points_forts}.rb`, `db/migrate/20260926090*`
- `app/controllers/admin/*`, `app/controllers/concerns/tri_par_completude.rb`, `app/models/concerns/{galerie_photos,fiche_completude}.rb`
- `lib/tasks/declic_dates_rapport.rake`, `app/controllers/admin/base_controller.rb`, `db/seeds.rb`
- Tests : `test/models/{conversion_dates,opportunity_dates,points_forts,seeds,fiche_admin}_test.rb`, `test/controllers/admin_{acces,fiches}_test.rb`
