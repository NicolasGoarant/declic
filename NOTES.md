# NOTES
Détail ancien (fiches, bateaux, vivants, toits, accueil, géoloc…) : `git log -p NOTES.md` (version du 27/10 avant condensation).

## Règle éditoriale (fiches)
- **Opportunité** : invite à agir (datée ou permanente `schedule_text`, bouton `cta_button_text`/`cta_button_url`). **Belle Histoire** : récit sans appel à l'action (ni horaire ni bouton) ; dit où trouver la personne, sa parole, la source.

## Fait
- **Prod = app Heroku `declic-nancy-paris-eu` (eu)**, www.declic.site. Déployer : `git push https://git.heroku.com/declic-nancy-paris-eu.git main:main` (remote `heroku` local obsolète ; l'app us est secondaire, ne rien y pousser). `origin/main` GitHub peut être en retard.
- **Trains SNCF RÉELS EN PROD (27/10, 118f31a, v8 eu)** : l'accueil joue de vrais trains aux horaires GTFS SNCF (GTFS-RT = heure seulement, pas de retard affiché), repli auto sur la boucle décorative. Rails : `app/services/trains/*`, `GET /trains/prochains.json` (`?a=HH:MM` hors prod), `db/trains/nancy.json` (`rake trains:extrait SORTIE=livre`), page `/sources`. JS : `diorama/trains_reels.js` (`Plan`) + `trains.js` (`Scene` dynamique, `demarrerReel`, `aiguiller`). Crochets : `?trains-reel=0`, `?trains-heure=HH:MM` (hors prod). Vérifié en prod : relais 200, train réel joué dans Chromium.
- **R2 `trains-v1`** : `itineraires-trains.json` publié le 27/10 (29 itinéraires unitaires) via nancy-3d `publier-r2.py --jeu trains-v1` (source ajoutée à `JEUX`, non commitée) ; paquet régénéré par `exporter.py` (scenarios inchangés : seul le texte du journal varie).
- **Correctif A (118f31a)** : `dalles_vers_sol` de `occlusion-trains-jv2.json` appliquées à la carte de classes de l'ambiance (niveau 8, `couches.js classesVersSol`, `ambiance.js versSol`, `diorama_controller abrisVersSol`, témoin `?ambiance-abris=0`). Gain net mais partiel : le résidu près des rails est du vrai bâti (prismes qui débordent) ; élargir la règle effacerait des façades. Niveaux 6-7 (masque du bâti) non traités.
- **Défauts du 27/10** : (1) esplanade près de la place Maginot (dalle n8 66/38) — l'ambiance laisse le « feuillage au sol » (vert sur sol de la propriété) recevoir la lumière des places, sans teinte des parcs (37f48a7, eu) ; l'option B littérale (déclasser ce vert) jaunissait les pelouses en hiver. (2) lucarnes en double au n8 et en dessous (fond nancy-3d, pas les mâts) : greffe `v20-lucarnes-n8.py` (nancy-3d, non commité), 959 dalles n8→n0 publiées sur R2 + purge 6 origines ; « échelles » de lucarnes côté cour laissées de côté.
- **Échelles de lucarnes côté cour (28/10, nancy-3d ee6cbb9)** : `V2_LUCARNES_RUE=1` (défaut, v01 + copie portée n9) ne garde sur les mansardes que les lucarnes côté rue (sonde 2 m au-delà de l'égout : hors bâti, < 15 m d'une voirie). 798 bâtiments ; 2 592 dalles n9→n0 publiées R2 + purge 6 origines. Deux-pans inchangés. `nuit-chaude-v1` non concernée.
- Diorama en local : `http://localhost:3003` ou `:3000` (CORS R2), JAMAIS `127.0.0.1`. Purge Cloudflare des dalles R2 : une purge par variante Origin (mémoire `purge-cloudflare-origin`).

## Tests
- `bin/rails test` : 135 verts (27/10). Système : `CHROME_NO_SANDBOX=1`, `SE_CHROMEDRIVER` vers chromedriver = Chrome ; `calques_test.rb:48`/`:112` échouent aussi sur main, `geoloc_auto_test`/`accueil_test.rb:49` intermittents.

## Reste à faire
- GTFS : aucun service Nancy le 31/10/2026 (trou de la source) → boucle ce jour-là ; surveiller le rafraîchissement hebdo de l'extrait.
- Quai plausible choisi côté client (voie à quai non publiée) ; Intercités rendus en TER (pas de sprite).
- Éventuel correctif B (propriété jeu-vidéo régénérée côté nancy-3d, R2 + purge par Origin) si des défauts de rectangles clairs reviennent, y compris aux niveaux 6-7.
- Non commités : `docs/audit*.md`, maquettes `docs/maquettes/*.png`, `.playwright-mcp/` (à trier/ignorer).
- Géoloc auto (branche `fix-geolocalisation-auto`, non déployée) ; photos sources minuscules ; `source_name` sans URL ; champs à surveiller en prod (`Story#thematique`/`quote`/`source_published_on`).

## Fichiers clés
- Accueil/fiches : `app/views/labo/accueil.html.erb`, `app/views/accueil/*`, `app/views/{opportunities,stories}/show.html.erb`, `app/helpers/labo_helper.rb`.
- Diorama : `app/javascript/controllers/diorama_controller.js`, `app/javascript/diorama/{trains,trains_reels,ambiance,couches,mobiles,vivants}.js`.
- Trains : `app/services/trains/`, `app/controllers/trains_controller.rb`, `lib/tasks/trains.rake`, `db/trains/nancy.json`, nancy-3d `rapports/animations-v1/trains-demo/animation/{exporter,unitaires}.py`.
