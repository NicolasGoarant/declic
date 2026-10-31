# Audit de la branche `veille-auto` — 28/10/2026

Audit en lecture seule (`git show` / `git ls-tree`, sans bascule de branche, sans exécuter le code ni les tests). Fait suite à `docs/audit-ingestion-ia-2026-10-28.md`.

## Résumé

1. `veille-auto` (locale seule, tête `02866ed`, 13/10/2026, 121 commits d'avance sur `main`, non fusionnée) est la version aboutie du module : namespace `Veille::`, écran `/admin/veille`, 6 connecteurs, 21 fichiers de tests, doc.
2. Les Opportunités sont **déjà prises en charge de bout en bout** : collecte, dédoublonnage, tri par l'IA, relecture, bouton « Valider » qui crée une `Opportunity` inactive.
3. Les quatre classes demandées existent, mais ont changé de forme : les `RawIngester`, `AiEnricher` et `StoryDrafter` du namespace `Veille::` ne sont plus ceux de `ingestion-ia`, et ils écrivent dans une table `veille_candidates` (plus `raw_ingestions`).
4. Reste à faire pour les Opportunités : la rédaction par l'IA (seules les Belles Histoires en ont une), l'horaire récurrent et la date de début lus par l'IA vers les bons champs, et trois sources non branchées ou bloquées.
5. Le code est en revue, pas en production : il suppose un déploiement (Heroku Scheduler, clés) qui n'est pas documenté comme fait.

## 1. Branche

| Branche | Locale / distante | Tête | Rapport à `main` |
|---|---|---|---|
| `veille-auto` | locale seule | `02866ed` (13/10/2026) | +121 commits, 482 fichiers modifiés (beaucoup sans rapport : diorama, fiches, tests système) |

Commits propres au module : `555b824` (socle `AnthropicClient`), `8e44bea` (Qualifier + Drafter), `8b97699` (admin + rake + tests), `7a42e18` (fusion de `veille-belles-histoires`), `038b1bc` (champs du candidat), `c2c62f8` (client HTTP + connecteurs 1 à 6), `d2342f6` (`RawIngester`, `AiEnricher`, `StoryDrafter`, plafond de 30, import xlsx), `fa8657d` (écran filtres/badges/Valider), `a1f6870` (arrêt après 3 erreurs IA), `02866ed` (doc + NOTES).

## 2. Briques

| Brique | État actuel | Ce qu'il manque pour les Opportunités |
|---|---|---|
| `Veille::RawIngester` (`app/services/veille/raw_ingester.rb`, 49 l.) | **Fonctionnel.** Entrée : liste de `Veille::Item` fournie par un connecteur. Sortie : `Bilan(crees, doublons, hors_zone, passes, invalides)`, lignes `veille_candidates` (`status: pending`). Écarte d'emblée hors Grand Nancy et événements passés ; dédoublonne par URL ou titre normalisé + date. Aucun appel IA. | Déjà pensé pour les deux types. Manque : une trace du texte source après écartement (aucune, volontairement), pas d'idempotence sur modification (un item revu n'est pas mis à jour). |
| `Veille::AiEnricher` (`app/services/veille/ai_enricher.rb`, 151 l.) | **Fonctionnel, le plus abouti.** Haiku 4.5 (`claude-haiku-4-5-20251001`), JSON Schema, 700 tokens max. Pour un candidat : type (opportunité ou belle histoire selon la règle éditoriale), catégorie parmi `Opportunity::CATEGORIES`, commune du Grand Nancy, `date_debut`/`date_fin`, `regime` (permanent), résumé en 2 phrases, `confiance` 0-100, `motif`. Règles codées et testables sans réseau : sources officielles forcées en « opportunité », écarte hors zone et passé, contrôle anti-copie (plus de 15 mots consécutifs identiques → résumé retiré, `a_verifier`). | **Pas de lien d'inscription ni de contact** : le CTA est posé à la validation sur l'URL source (« Pour en savoir plus »). Pas de `application_deadline`. Pas de description longue (résumé de 2 phrases seulement) : une Opportunité validée est donc courte. Pas de lieu précis (commune seulement, `location = commune`). |
| `Veille::StoryDrafter` (`app/services/veille/story_drafter.rb`, 56 l.) | **Fonctionnel.** Sonnet (`claude-sonnet-5`), brouillon d'environ 120 mots à partir du titre et du résumé reformulé (jamais de l'article). Ajoute en code la mention de source et « Accord de la personne : à obtenir ». | Réservé aux Belles Histoires (appelé par `Runner` seulement si `item_type == "belle_histoire"`). **Il n'existe pas de rédacteur d'Opportunité** : l'ancien `OpportunityDrafter` d'`ingestion-ia` n'a pas été repris. À créer ou à assumer (résumé court suffisant). Vérifier l'identifiant de modèle `claude-sonnet-5` (voir §5). |
| `AnthropicClient` (`app/services/anthropic_client.rb`, 134 l.) | **Fonctionnel, amélioré** par rapport à `ingestion-ia` : timeout, nombre de retries et modèle réglables ; erreurs réseau et JSON illisible enveloppées (`ConnectionError`, `MalformedResponseError`) ; 401 et 429 typés. Testé (`test/services/anthropic_client_test.rb`). | Pas de backoff sur 429/5xx (un 429 compte comme erreur IA, arrêt après 3 d'affilée), pas de batch API. Suffisant pour 30 éléments par jour. |

### Briques annexes

| Élément | État | Remarque |
|---|---|---|
| `Veille::Runner` (108 l.) | Fonctionnel. `quotidien` = connecteurs 1 à 5, `hebdomadaire` = presse. Plafond de 30 enrichissements, priorité par source, arrêt après 3 erreurs IA d'affilée ou sur 401, coût estimé en log (`Veille::Cout`). | Tout le reste du pipeline en dépend. |
| `Veille::Qualifier` (111 l., Haiku) et `Veille::Drafter` (135 l., Sonnet) | Fonctionnels. Passes A/B de la veille Belles Histoires **par collage manuel** (import d'URL, rédaction depuis l'écran dans la requête web, 22 s). | Spécifiques aux Belles Histoires ; redondants en partie avec `AiEnricher`/`StoryDrafter`. Deux circuits coexistent. |
| `Veille::Validation` (68 l.) | Fonctionnel. « Valider » crée une `Opportunity` ou une `Story` **inactive** ; exige commune et résumé ; efface `full_text` ensuite. | Renseigne `starts_on`, `ends_on`, `schedule_text`, `cta_button_text`, `cta_button_url`, `source_name`. Ne renseigne pas `application_deadline`, `organization`, `contact_*`, ni de lieu précis. |
| Connecteurs (`app/services/veille/connectors/*`) | Engagement (clé requise), AgendaNancy, FormationLorraine (UIMM seul), Transentreprise, GazetteFrance, Presse. Tous respectent `robots.txt` (`Veille::Http`, `RobotsPolicy`) et ne lèvent jamais d'exception (statuts `ok/refuse/erreur/inactive/partiel`). | Voir §4. |
| `Veille::Candidate` / `Veille::Source` | Fonctionnels. `veille_candidates` : url unique, statut (`pending/a_verifier/retenu/ecarte/publie`), score, type, dates, régime, résumé, fiabilité, `opportunity_id`. | `veille_sources` (table des sources saisies à la main) sert au circuit « import d'URL » ; les connecteurs ne s'en servent pas. |

## 3. Branchement

**Branché dans l'admin, avec deux moteurs de collecte.**

- Admin : `namespace :veille` dans `config/routes.rb` (sous `admin`), `Admin::Veille::CandidatesController` (index avec filtres type/catégorie/origine/date et onglets de statut, `retenir`, `ecarter`, `a_verifier`, `valider`, `rediger`, `publier`) et `SourcesController`. Authentification via `Admin::BaseController`. Vues en Turbo Stream, layout dédié `veille.html.erb`.
- Collecte : **tâches rake** `veille:quotidien`, `veille:hebdomadaire` (lundi, ou `FORCE=1`), `veille:import[fichier]`, `veille:import_xlsx[fichier]`. La doc les prévoit sur **Heroku Scheduler** (quotidien + hebdomadaire), ce qui est un réglage de la plateforme, **non vérifiable dans le dépôt** (le `Procfile` ne contient que `web`, aucun worker).
- Rédaction : dans la requête web, sans job (budget de 30 s d'Heroku).
- Je n'ai pas trouvé de lien vers `/admin/veille` depuis le layout `admin.html.erb` ; l'écran se rejoint par l'URL (à confirmer en lançant l'appli).

## 4. Périmètre : Belles Histoires ou générique ?

**Générique** (opportunités et belles histoires), avec un écart de maturité :

| Aspect | Opportunités | Belles Histoires |
|---|---|---|
| Collecte | Sources 1 à 5 (JeVeuxAider, agenda Grand Nancy, UIMM, Transentreprise, Gazette) | Presse (RSS), import d'URL, repérage xlsx |
| Qualification | `AiEnricher` (type, catégorie, commune, dates, résumé) | idem + `Qualifier` (score) |
| Rédaction | Résumé de 2 phrases uniquement | `StoryDrafter` (120 mots) ou `Drafter` (3 phrases, depuis le texte collé) |
| Création de fiche | `Validation#creer_opportunite` | `Validation#creer_histoire` ou `publier` |
| Date / régime | Oui (`starts_on`, `ends_on`, `schedule_text`) | `happened_on` seulement |
| Lien d'inscription | Lien source posé en CTA | Sans objet |

État des sources au 13/10/2026 (d'après `docs/veille-auto.md`, non retesté) :

- JeVeuxAider / Engagement : **clé `ENGAGEMENT_API_KEY` requise** (401 sans), « non testée en réel ».
- Agenda Grand Nancy : répond, 4 rubriques retenues sur plusieurs.
- Formation : UIMM Lorraine répond ; **`formation.grandest.fr` non branchée** (application Angular, API inconnue).
- Transentreprise : répond, 0 offre Nancy ce jour-là ; texte réduit à l'accroche.
- La Gazette France : répond.
- Presse : L'Est Républicain ok ; **France 3 refusé par `robots.txt`** ; alertes e-mail non implémentées.

Manques propres aux Opportunités : pas de source associative locale (Maison des associations, agendas d'assos), pas de collecte d'événements récurrents (la logique de régime ne produit qu'un texte libre).

## 5. Tests, configuration, documentation

- **Tests** : 21 fichiers sous `test/.../veille/` (client, enricher, qualifier, drafter, story_drafter, raw_ingester, runner, validation, connectors, robots, page_fetcher, grand_nancy, xlsx, candidats, sources, contrôleurs admin), avec un `FakeAnthropicClient` ; fixture `test/fixtures/files/veille/agenda_extrait.json`. `NOTES.md` indique `bin/rails test` : 135 verts le 27/10 sur `main`, **non exécuté ici sur `veille-auto`**.
- **Configuration** : `ANTHROPIC_API_KEY` (aucun défaut), `ANTHROPIC_MODEL` (défaut `claude-sonnet-5`, non utilisé par la veille, qui fixe son modèle par passe), `ENGAGEMENT_API_KEY`. Pas de `.env.example` ni de `app.json`. Gem `roo` ajoutée pour l'import xlsx.
- **Identifiant de modèle (corrigé le 28/10)** : `claude-sonnet-5` (Drafter, StoryDrafter, initialiseur) **existe** : `GET /v1/models/claude-sonnet-5` répond 200 (Claude Sonnet 5, 29/06/2026). Ma première note le donnait pour invalide, à tort. Un vrai appel `/v1/messages` n'a pas pu être fait : crédits API épuisés (HTTP 400, « credit balance is too low »).
- **Documentation** : `docs/veille-auto.md` (chaîne, sources, Heroku Scheduler, variables) et `docs/veille.md` (circuit Belles Histoires, règle `full_text`). `docs/veille.md` n'a pas été mis à jour pour le circuit automatique.
- **Reste de l'ancien module** : le modèle `RawIngestion` est encore présent sur la branche alors que `RawIngester`, `AiEnricher` et `StoryDrafter` racine ont disparu ; les services `RssFetcher`/`IcsFetcher` subsistent. Probablement du code mort, à confirmer.
- **Hygiène** : la branche cumule des changements sans rapport (diorama, fiches, tests système). Avant d'étendre, vérifier ce qui doit remonter dans `main` avec `git diff main...veille-auto -- app/services/veille app/models/veille app/controllers/admin/veille`.

## 6. Pistes pour étendre aux Opportunités (pour décision, rien n'a été fait)

1. Corriger/confirmer l'identifiant de modèle Sonnet avant tout.
2. Décider si une Opportunité mérite une rédaction IA (description plus longue, lieu précis, lien d'inscription) ou si le résumé de 2 phrases suffit ; dans le premier cas, créer un `OpportunityDrafter` calqué sur `StoryDrafter`.
3. Faire remonter de l'IA l'`application_deadline`, le lien d'inscription et le lieu, et les mapper dans `Validation#creer_opportunite`.
4. Brancher les sources manquantes (clé Engagement, `formation.grandest.fr`, agendas associatifs).
5. Supprimer ou documenter le double circuit (`Qualifier`/`Drafter` manuels vs `AiEnricher`/`StoryDrafter` automatiques) et le code mort.

## Fichiers concernés (branche `veille-auto`)

Services
- `app/services/anthropic_client.rb`, `app/services/engagement_api.rb`
- `app/services/veille/{runner,raw_ingester,ai_enricher,ai_pass,story_drafter,qualifier,drafter,validation,item,cout,grand_nancy,http,robots_policy,page_fetcher,text,xlsx_importer}.rb`
- `app/services/veille/connectors/{base,engagement,agenda_nancy,formation_lorraine,transentreprise,gazette_france,presse}.rb`

Modèles et base
- `app/models/veille.rb`, `app/models/veille/{candidate,source}.rb`, `app/models/raw_ingestion.rb` (reste)
- `db/migrate/20260905090000_create_veille_sources.rb`, `20260905090100_create_veille_candidates.rb`, `20260905090200_add_veille_candidate_to_stories.rb`, `20261013090000_add_veille_auto_to_veille_candidates.rb`

Admin
- `app/controllers/admin/veille/{base,candidates,sources}_controller.rb`
- `app/views/admin/veille/candidates/*`, `app/views/admin/veille/sources/*`, `app/views/layouts/veille.html.erb`
- `config/routes.rb` (namespace `veille`)

Configuration et tâches
- `config/initializers/anthropic.rb`, `lib/tasks/veille.rake`, `Gemfile` (`roo`), `Procfile`

Documentation
- `docs/veille.md`, `docs/veille-auto.md`

Tests
- `test/services/anthropic_client_test.rb`, `test/services/veille/*` (dont `fake_anthropic_client.rb`, `support.rb`), `test/models/veille/*`, `test/controllers/admin/veille/*`, `test/fixtures/files/veille/agenda_extrait.json`
