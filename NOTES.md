# NOTES (détail ancien : `git log -p NOTES.md`, versions du 27/10 et du 07/11)
## Règle éditoriale (fiches)
- **Opportunité** : invite à agir (datée ou permanente `schedule_text`, bouton `cta_button_text`/`cta_button_url`). **Belle Histoire** : récit sans appel à l'action ; dit où trouver la personne, sa parole, la source.
## Prod et déploiement
- **Prod = `declic-nancy-paris-eu`** (www.declic.site, pipeline `declic-veille`). Déployer : `git push https://git.heroku.com/declic-nancy-paris-eu.git main:main`. **Jamais l'app US `declic-nancy-paris`** (legacy, v369, partage base et bucket ; 3 vieux clones gardent ce remote : `declic_heroku`, `declic_backup_2025-09-28_1709`, `_2025-09-29_0325`). `origin/main` GitHub peut être en retard.
- **Procfile `release: bin/rails db:migrate` (07/11, 3013ae2, v32)** : migrations jouées avant bascule des dynos web (vérifié : release finie 16:18:04, web redémarré 16:18:06) ; si elle échoue, l'ancien code reste. Plus besoin de maintenance + `heroku run db:migrate`. Les review apps du pipeline la jouent aussi (avant leur `postdeploy` `db:schema:load`).
- **v32 (07/11) = `main` entier en prod** : catégorie ecologie, veille des communes, bateaux la nuit, nuages/brouillard/joggeurs. Aucune base de sauvegarde automatique (base externe, pas de pg:backups) ; dump du 01/11 : `~/Documents/declic_sauvegardes/` (`pg_restore` ≥ 18).
- Diorama en local : `localhost:3003`/`:3000` (CORS R2), jamais `127.0.0.1`. Purge Cloudflare des dalles : une par variante Origin (mémoire `purge-cloudflare-origin`).
## Historique condensé (EN PROD)
- Trains SNCF réels (27/10, `app/services/trains/*`, `diorama/trains_reels.js`, `/sources`) ; lucarnes côté rue et coupes de mansardes (`SURCOUCHES`, R2) ; lotissement 2025 (01/11) ; Belles Histoires sans thématique (31/10 ; **suite : supprimer `stories.thematique`**, vide sur les 51).
- Taxonomie Pratiquer/Découvrir (01/11) ; perf carte (02/11, `rapports/perf-carte-2026-11-02.md` ; reste : pose des vivants, photos d'accueil 5 Mo) ; dépublication des fiches terminées (03/11 ; fiche 1124 encore publique, texte libre).
- **Catégorie ecologiser → ecologie (07/11, v32)** : migration en release : 19 opportunités + 3 candidats. Vérifié : comptes inchangés ailleurs, filtre/pins/image par défaut, `/admin/opportunities?category=ecologiser` → mêmes 19 (`Categorie.cle_actuelle`). App US : ces 19 fiches y sont invalides/sans icône, effet de bord accepté.
- **Voiles et joggeurs (07/11, v32)** : vus en prod (nuages en Jour, brouillard, joggeurs ~6 % des piétons), 0 erreur JS, 43-60 images/s. Crochets `?nuages=0`, `?brouillard=0`, `?joggeurs=0`, `?voiles-t=S`. Reste : promeneurs de chiens, vent réel. Bateaux : plancher 0,08 la nuit (cadence non jugée).
## Veille auto (EN PROD ; `docs/veille.md`, `docs/veille-auto.md`)
- `/admin/veille` (Basic auth), Valider publie, `Opportunity.publiques`. Sources du quotidien dans le code (`Runner::QUOTIDIEN` : Agenda Grand Nancy + `Connectors::Communes`, 8 communes dont 6 sur décision du président) ; Transentreprise retiré (mentions légales). Presse = collage manuel. Plafond IA 15 $/mois.
- `AiEnricher` corrigé (annonce/actualité, dates plausibles) : en prod depuis v32. À relire sur `declic-communes-review` : #23, #12, #34-37 ; **app à supprimer** (`heroku apps:destroy`).
- **À FAIRE (urgent)** : régénérer `ANTHROPIC_API_KEY` (affichée en clair le 02/11) et la mettre à jour partout, surtout la prod. **Tâche Scheduler à créer à la main** : `heroku addons:open scheduler -a declic-nancy-paris-eu` → `rake veille:quotidien`, 05:00 UTC. Saisir la commune des 15 candidats « à localiser ». Confirmer Maxéville.
- Sources à décider : RNA, HelloAsso, `ENGAGEMENT_API_KEY` ; GNI (demander autorisation). Entreprendre : fiches permanentes (Grand Test, Matinales, Pitch Night).
## Tests, reste à faire
- `bin/rails test` : 501 verts (03/11). Système : `fiches_test.rb:65/71` (fiche passée) échoue ; intermittents `calques_test.rb:81/112`, `ambiances_test.rb:58/83/131`. Lancer avec `CHROME_NO_SANDBOX=1 CHROME_BIN=~/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome SE_CHROMEDRIVER=~/.cache/selenium/chromedriver/linux64/155.0.8059.84/chromedriver`.
- Images Belles Histoires : Sven 635 sans photo, Nooki 634 droits presse à trancher. `/stories/new` : 404 `/assets/tailwindcss`. Légende bureau `b3815e4` en prod depuis v32 (non revérifiée). Non commités : `docs/analyse-corpus/`, `docs/maquettes/*.png`, `.playwright-mcp/`.
## Fichiers clés
- Accueil/fiches : `app/views/labo/accueil.html.erb`, `app/views/accueil/*`, `app/views/{opportunities,stories}/show.html.erb`, `app/helpers/{labo,fiches}_helper.rb`.
- Diorama : `app/javascript/controllers/diorama_controller.js`, `app/javascript/diorama/{trains,trains_reels,ambiance,couches,mobiles,vivants,voiles,meteo}.js`.
