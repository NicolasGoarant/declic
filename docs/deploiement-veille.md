# Déploiement de `veille-sources-v2` (14/11/2026)

**Constat du 14/11 (lecture seule).** `www.declic.site` = **`declic-nancy-paris-eu`** (v34, `4a71796`, pipeline `declic-veille`, Heroku Scheduler installé, tâche non créée). `declic-nancy-paris` (US, v369, legacy, sans clé IA) porte `declic.site`, `declic.fr`, `www.declic.fr` et **partage la même base Neon et le même bucket** : une migration jouée par l'app EU vaut pour les deux. **On ne déploie jamais l'app US.** La branche a 38 commits d'avance sur `main` et 0 de retard (fusion en avance rapide). 3 migrations à jouer, toutes additives (colonnes) : `20261114100000`, `20261114110000`, `20261114120000` ; durée : moins d'une seconde (100 lignes par table). Elles s'exécutent en phase `release` (`Procfile`) ; si elle échoue, l'ancien code reste en ligne.

Notation : `EU=declic-nancy-paris-eu`, `US=declic-nancy-paris`.

## 0. Avant de pousser
```
git switch veille-sources-v2 && bin/rails test            # 654 verts attendus
bin/rails veille:exporter_candidats                        # tmp/candidats-veille-AAAA-MM-JJ.json (148 candidats, non versionné)
pg_dump "$(heroku config:get DATABASE_URL -a $EU)" -Fc -f ~/Documents/declic_sauvegardes/declic-prod-avant-veille-v2-$(date +%F).dump   # seul filet : ni pg:backups ni retour arrière de migration
```
Variables (une seule fois ; chaque `config:set` redémarre le web) :
```
read -rs K && heroku config:set ANTHROPIC_API_KEY="$K" -a $EU; unset K    # la nouvelle (finit par EwAA) ; la prod porte encore l'ancienne (KAAA)
heroku config:set VEILLE_BUDGET_MENSUEL=15 VEILLE_PRESSE_ACTIVE=false -a $EU
heroku config:get ANTHROPIC_API_KEY -a $EU | grep -o '.\{4\}$'              # EwAA
```
`ADMIN_SANS_MOT_DE_PASSE` ne doit exister ni sur EU ni sur US (absente le 14/11) ; ne jamais la créer.

## 1. Fusion, push, build
```
git switch main && git merge --ff-only veille-sources-v2
git push https://git.heroku.com/declic-nancy-paris-eu.git main:main      # jamais le remote dokku-test, jamais l'app US
heroku releases -a $EU -n 3 && heroku releases:output -a $EU              # v35 « Deploy … » ; sortie de db:migrate (3 migrations « migrated »)
heroku logs -n 100 -a $EU | grep -iE "error|H1[0-9]|R1[0-9]"             # rien attendu
git push origin main                                                       # GitHub (33 commits de retard, facultatif)
```
Vérifier ensuite `heroku run -a $EU "bin/rails runner 'puts ActiveRecord::Base.connection.migration_context.current_version'"` → `20261114120000`, et que l'app US répond (`curl -sI https://declic-nancy-paris-bb639ed6aeca.herokuapp.com | head -1` → 200 : elle tourne sur la base migrée, les colonnes ajoutées ont une valeur par défaut).

## 2. Journal des coûts du banc
```
heroku run -a $EU "rake veille:reporter_banc CSV=rapports/banc-essai-2026-11-11.csv DATE=2026-11-11"   # 52 appels, ≈ 0,42 $
heroku run -a $EU "rake veille:reporter_banc CSV=rapports/banc-essai-2026-11-14.csv DATE=2026-11-14"   # 52 appels, ≈ 0,46 $ (2e banc ; décision à confirmer)
```
Idempotent par date (rien reporté si déjà fait). Le tri réel du 14/11 (1,77 $, 235 appels) n'est pas reporté : il a été payé en local.

## 3. Candidats triés en local (sans repayer l'IA)
Le fichier n'est pas dans le slug : on l'envoie par l'entrée standard.
```
heroku run --no-tty -a $EU "rake veille:importer_candidats FICHIER=- DRY_RUN=1" < tmp/candidats-veille-2026-11-14.json
#   attendu (simulation sur les 100 URL de la prod) : 70 créé(s), 78 ignoré(s), 0 refusé(s)
heroku run --no-tty -a $EU "rake veille:importer_candidats FICHIER=-" < tmp/candidats-veille-2026-11-14.json
```
Idempotent (clé : URL, puis même titre + même date), jamais d'écrasement, aucune fiche, aucune publication. Sans `full_text` : pour **Valider** une fiche importée, la rédaction repart de l'extrait.

## 4. Heroku Scheduler (à la main, le CLI ne crée pas la tâche)
`heroku addons:open scheduler -a $EU` → *Add job* : commande `rake veille:quotidien`, fréquence **Every day**, heure creuse **05:00 UTC** (06:00/07:00 à Nancy), dyno Standard-1X. Rien sur l'app US.

## 5. Contrôles après déploiement
- `https://www.declic.site/admin/galerie` (Basic auth) : 200 ; compteurs par statut (70 candidats importés, 15 en attente existants) ; bandeau de plafond absent.
- Accueil, carte, une fiche : inchangés (≈ 136 fiches publiques, 51 belles histoires).
- Coût du mois : `heroku run -a $EU "rake veille:cout"` → ≈ 0,48 $ déjà journalisés + 0,42 $ (+ 0,46 $) du banc.
- Lendemain du premier passage du Scheduler : `heroku logs -a $EU --ps scheduler` et `rake veille:cout`.

## 6. Retour arrière
```
heroku rollback v34 -a $EU        # code seul : les 3 colonnes restent, l'ancien code les ignore (valeurs par défaut)
```
Neutraliser le Scheduler : supprimer le job dans le tableau de bord (ou `heroku config:set VEILLE_BUDGET_MENSUEL=0 -a $EU` : plafond à zéro, plus aucun appel IA). Les candidats importés se retirent par un `DELETE` ciblé (aucune fiche créée). Restauration de la base seulement depuis le dump du §0 (`pg_restore` ≥ 18) : elle vaut pour les deux apps.

## 7. Fiche de test à supprimer
« TEST variantes WebP (à supprimer) » : **absente de la production** (aucune fiche de ce titre, ni « test » ni « variante », parmi 174 opportunités et 51 belles histoires, vérifié le 14/11 sur la base partagée). Locale : id 343, doublon de la 323 — supprimée en local. Rien à supprimer en prod ; si elle apparaissait, le faire à la main dans `/admin/opportunities`.

## 8. Déroulé réel (14/11/2026)
- Sauvegarde : `~/Documents/sauvegardes-declic/declic-prod-2026-11-14.sql.gz` (pg_dump **18** requis : `/usr/lib/postgresql/18/bin/pg_dump`, le 16 refuse le serveur Neon 18 ; dump SQL texte, à restaurer avec `psql`).
- Répétition : base locale `declic_prod_copy` (restauration + 3 migrations + import 70/78/0), appli sur le port 3010 avec `DATABASE_URL=postgresql:///declic_prod_copy` ; toutes les pages en 200. `db:migrate` sur Postgres réécrit `db/schema.rb` : `git checkout db/schema.rb`. Aucune catégorie périmée en prod (174 fiches valides).
- Déploiement : tests 654 verts, `main:main` vers `declic-nancy-paris-eu` = **v36** (3 migrations en release, OK) ; v37 = `VEILLE_BUDGET_MENSUEL=15`, `VEILLE_PRESSE_ACTIVE=false` (v35 = clé API, pas du code : retour arrière = v34).
- Prod : `reporter_banc` ×2 (52 + 52 appels), import 70 créés / 78 ignorés / 0 refusé (simulation identique).
- Contrôles : pages publiques 200, `/admin/*` 401 sans identifiants, journaux sans erreur (un scan bot `/wp-admin`).
- Essai `veille:quotidien` à la main (`VEILLE_BUDGET_MENSUEL=4.40` sur la commande = plafond ~3 $ de plus, presse inactive) : 160 éléments retenus par les sources (agenda 117, communes 43), 84 nouveaux, 76 doublons, 30 triés (1 écarté, 14 à vérifier), 54 en attente (limite de 30 par passage), 0 erreur IA, coût **0,455 $**. Statuts après : pending 95, à vérifier 16, écartés 58, publiés 85 (254 candidats). Dépense du mois : 1,82 $ / 15 $.
- Domaines : `declic.fr`/`www.declic.fr` pointent vers un autre site (OVH, mobilier urbain), `declic.site` vers OVH avec HTTPS en échec (reset TLS) : l'app US ne sert que son URL herokuapp ; ne pas la mettre à jour.
- GitHub : `origin/main` poussé (01767ab). Scheduler non créé (à faire par Nicolas).

## 9. Correctif « Aujourd'hui » dans les textes collectés (branche `fix-textes-relatifs`, 15/11/2026, DÉPLOYÉ v38)
**Cause** : l'API de l'agenda du Grand Nancy renvoie `duringDateText` écrit pour le jour même (« Aujourd'hui de 18h30 à 20h » : 196 événements sur 348 ; « Ce soir » et « Ce week-end » 1 fois chacun) ; la date absolue est dans `beforeDateText`, `startDate`, `endDate` et `dateList`. Le connecteur recopiait `duringDateText` dans le texte. Les dates stockées (champs `starts_on`/`ends_on`) étaient justes : « Le vivant et l'art contemporain », « Les nouveautés » et « Lab'Oratoire Magique » ont bien lieu le mercredi 16/12/2026. La sous-catégorie égale à la rubrique (160 événements sur 348) produisait « Conférence - Rencontre. Conférence - Rencontre. ».
**Correctif** : `Veille::TextesRelatifs` (appelé par `Item#to_candidate_attributes`, donc pour tous les connecteurs) remplace le segment relatif par la date absolue pour un événement d'un jour (« Mercredi 16 décembre 2026 de 18h30 à 20h »), le retire sinon, et supprime les segments identiques consécutifs. Seuls les segments courts qui commencent par le mot relatif sont touchés (pas de phrase de presse). Événements à occurrences multiples : créneau = `startDate` → `endDate` (première à dernière date) ; la liste des occurrences vient de `beforeDateText` + horaire (« … à 14h »). Limites de la source : `endDate` ≠ dernière date du texte pour « Initiation à la MAO » (20/01 contre « samedi 20 février ») ; `beforeDateText` fausse pour « Les nouveautés » (« 16 septembre ») et « Lab'Oratoire » (« mercredi 15 décembre ») : on n'utilise pas ce texte pour un événement d'un jour.
**Échantillon de contrôle** : 5 « Événement passé » vérifiés sur nancy.fr (#136 30/10, #110 17/10, #124 et #123 25/10, #105 16-17/10) : tous réellement passés, aucune erreur de lecture de date (#123 est signalé « Évènement annulé » sur la source).
**Audit de production (lecture seule, 15/11)** : candidats non publiés 169 (56 avec mot relatif, 27 avec doublon) ; candidats publiés 85 (44 / 23, internes, non touchés) ; opportunités 174 : 1 occurrence (#1786, prose) ; belles histoires 51 : 17 « Aujourd'hui/hier » en prose du récit (légitimes). **Aucune correction à faire sur les fiches publiées.**
**Déployer** : tests, `git checkout main && git merge --ff-only fix-textes-relatifs`, push `main:main` vers `declic-nancy-paris-eu` seulement (pas de migration). **Nettoyer la production** : `heroku run -a declic-nancy-paris-eu "DRY_RUN=1 bin/rails veille:nettoyer_textes"` (attendu : ~56 candidats listés, d'après l'audit ; essayé en local sur la copie du 14/11 : 29 nettoyés puis 0), relire, puis sans `DRY_RUN`. La tâche ignore les publiés et tout `full_text` collé à la main ou récupéré sur la page (l'extrait, lui, est nettoyé).

**Déroulé réel (15/11/2026)** : 665 tests verts ; sauvegarde `~/Documents/sauvegardes-declic/declic-prod-2026-11-15-avant-nettoyage.sql.gz` (pg_dump 18, 210 Ko, gzip lisible) ; ff-only de `main` (1b68f95) puis push vers `declic-nancy-paris-eu` : **v38**, release OK, sans migration (retour arrière de code : v36). Contrôles : `/` et `/sources` 200, `/admin/galerie` 401, aucune erreur liée au déploiement. Dry-run : **61 candidats** (et non ~56 : l'audit comptait 56 relatifs, la tâche touche aussi les doublons de libellés). Run réel : 61 nettoyés ; second passage : 0. Relecture en prod (#7, #172, #205 « Le vivant et l'art contemporain ») : date absolue (« Mercredi 16 décembre 2026 de 18h30 à 20h »), doublon retiré, plus de mot relatif. Aucune anomalie. Rappel : les événements déjà passés reçoivent leur date passée (#7 → 3 novembre) ; ils restent écartés/à relire normalement.

## 10. Pastille « +N » de la carte (branche `fix-carte-clusters`, 16/11/2026, DÉPLOYÉ v39)
**Correctif** : c35fcab, fichiers `app/javascript/controllers/diorama_controller.js`, `app/assets/stylesheets/accueil.css`, `test/system/grappes_test.rb` (+ captures `rapports/`). Aucune migration. Zoom si un zoom plus fort sépare le groupe, sinon bulle `.grappe` « N opportunités ici » avec un lien par fiche.

**Déroulé réel (16/11/2026)** : `main` fast-forwardé (3c24964 → c35fcab, `--ff-only`) ; `bin/rails test` : 665 tests, 0 échec ; système : 47 tests, 3 échecs (`veille_publication_test.rb:39` et `:52`, `fiches_test.rb:65`), reproduits seuls et identiques sur 3c24964, donc non liés au correctif (les timeouts du premier passage venaient du disque plein) ; `grappes_test.rb` : 4 verts. Production lue en lecture seule (catégories des fiches actives et publiques : formation 17, benevolat 14, decouvrir 38, pratiquer 31, entreprendre 17, ecologie 12 ; aucune hors liste). Push `main:main` vers `declic-nancy-paris-eu` seulement : **v39** (« Deploy c35fcab6 », 17:08), release command OK, dyno `web.1` up à 17:09:21, `/` 200.
**Vérification en production (Playwright, lecture seule, www.declic.site)** : filtre Découvrir (37), pastilles +4 et +3 visibles ; clic souris sur +4 (Stanislas) : zoom inchangé (6), bulle « 10 opportunités ici » avec 10 liens `/opportunities/<slug>`. Mobile 390 x 844 : même résultat (10 lignes) ; le haut de la bulle dépasse de l'écran quand la page est défilée (bulle à y = -134 dans la capture, à surveiller). Console : 0 erreur. Captures : `rapports/carte-clusters-prod-2026-11-16.png` (bureau) et `rapports/carte-clusters-prod-mobile-2026-11-16.png`.
**Retour arrière** : `heroku rollback v38 -a declic-nancy-paris-eu` (code seul, rien en base à défaire). GitHub `origin/main` à jour (c35fcab).

## 11. Bulle « N opportunités ici » en panneau fixe sur mobile (branche `fix-bulle-mobile`, 16/11/2026, DÉPLOYÉ v40)
**Correctif** : sur écran < 700 px, la liste devient un panneau fixe `.grappe-panneau` (`ouvrirPanneauGrappe`, `diorama_controller.js`, `accueil.css`), car la popup Leaflet suivait le cadre de la carte qui défile avec la page. Fermeture : ×, Échap, toucher dehors, mouvement de carte. Bureau inchangé (popup Leaflet). Aussi dans cette fusion : test d'ambiance à heure figée, galerie « Localiser d'abord ». Aucune migration. Tests : `grappes_mobile_test.rb`.

**Déroulé réel (16/11/2026)** : `main` fast-forwardé (f7a9caf → 407294d, `--ff-only`) ; push `main:main` vers `declic-nancy-paris-eu` seulement : **v40** (« Deploy 407294d4 », 18:37), release command (`db:migrate`) terminée avec statut 0 en ~6 s, `web.1` redémarré à 18:37:52, `/` 200. Aucune erreur dans les logs de démarrage.
**Vérification en production (Playwright, lecture seule, www.declic.site, filtre Découvrir)** :
- Mobile 390 x 844, clic sur le +4 de Stanislas : (a) page non défilée (scrollY 0) et (b) page défilée à la molette (scrollY 250) : panneau x 12→363, y 263,6→770 (écran 844 de haut), titre « 10 opportunités ici » à y 277,6 : entier à l'écran dans les deux cas ; 10 fiches, liste défilable, dernière fiche amenée dans la zone visible ; × et Échap ferment.
- Bureau 1440 x 900 : clic sur +4 = popup Leaflet « 10 opportunités ici » (10 liens), aucun panneau fixe, comme en v39.
- Console : 0 erreur.
- Captures : `rapports/carte-bulle-mobile-prod-non-defile-2026-11-16.png`, `rapports/carte-bulle-mobile-prod-defile-2026-11-16.png`, `rapports/carte-bulle-bureau-prod-2026-11-16.png`.
**Retour arrière** : `heroku rollback v39 -a declic-nancy-paris-eu` (code seul, rien en base à défaire).
