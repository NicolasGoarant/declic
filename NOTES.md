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

## Reste à faire
- Refonte des vues fiches Opportunité / Belle Histoire (maquettes `docs/maquettes/declic-maquette-fiche-*-v1.png`) ; champs nouveaux à ajouter aux formulaires admin (permit).
- Lancer `declic:dates_rapport` en production avant/après la migration ; version de transition puis suppression de start_date / end_date / highlights_*.
- Histoire #8 (jardin participatif) : plutôt une opportunité. Sections « Et moi, comment je peux avoir le Déclic ? » = appels à l'action, contraires à la règle. #9 : location à Saint-Malo pour un atelier dans les Vosges.
- Diorama (branche `refonte-accueil`) : zoom initial, bouquets de coordonnées identiques, publication R2, licence Géonancy.
- Préexistant : images Unsplash mortes en dev ; `home.html.erb.bak`.

## Fichiers clés
- `app/models/{opportunity,story,conversion_dates,points_forts}.rb`, `db/migrate/20260926090*`
- `lib/tasks/declic_dates_rapport.rake`, `app/controllers/admin/base_controller.rb`, `db/seeds.rb`
- Tests : `test/models/{conversion_dates,opportunity_dates,points_forts,seeds}_test.rb`, `test/controllers/admin_acces_test.rb`
