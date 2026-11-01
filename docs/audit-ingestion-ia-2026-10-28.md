# Audit de la branche `ingestion-ia` — 28/10/2026

Audit en lecture seule (`git show` / `git ls-tree`, aucune bascule de branche, aucun code modifié).

## Résumé

1. `ingestion-ia` existe en local uniquement (pas sur `origin`). Tête `ffd0718` (05/09/2026), 45 commits d'avance sur `main`, non fusionnée.
2. Les quatre classes existent et sont fonctionnelles (pipeline RSS/ICS/presse → IA → brouillon inactif), mais pilotées **uniquement par tâches rake** : rien dans l'admin, aucun job, aucun test.
3. Le périmètre est **déjà générique** : `AiEnricher` gère `:opportunity` et `:story`, et un `OpportunityDrafter` existe (non listé dans la demande).
4. Point important : la branche **`veille-auto`** (tête `02866ed`, 13/10/2026, 121 commits d'avance sur `main`) est le successeur de ce code : namespace `Veille::`, écran `/admin/veille`, ~25 fichiers de tests, doc, 6 connecteurs. À auditer avant d'étendre quoi que ce soit.
5. Ni `ingestion-ia` ni `veille-auto` ne sont dans `main` (`app/services/veille/` absent de `main`).

## 1. Branches trouvées

| Branche | Locale / distante | Tête | Rapport à `main` |
|---|---|---|---|
| `ingestion-ia` | locale seule | `ffd0718` (05/09/2026) | +45 commits, contient aussi des commits sans rapport (labo carte 3D, icônes, PDF) |
| `veille-auto` | locale seule | `02866ed` (13/10/2026) | +121 commits, successeur fonctionnel |
| `veille-belles-histoires` | locale | — | fusionnée dans `veille-auto` (`7a42e18`) |
| `feat/ingest-sources` | locale + `origin` | — | non examinée (nom proche, hors périmètre demandé) |

Commits propres au module sur `ingestion-ia` : `e02652f` (3a, client), `fe0da71` (3b, enricher), `0e0e4d1` (3c, atterrissage + drafter), `d457276` (enricher paramétré), `f611e9c` (StoryDrafter), `9d111c5` (`ingest:from_press`).

## 2. Briques

### Tableau par brique

| Brique | État actuel | Ce qu'il manque pour les Opportunités |
|---|---|---|
| `RawIngester` (`app/services/raw_ingester.rb`, 55 l.) | **Fonctionnel.** Entrée : une `Source` (kind `rss` ou `ics`). Sortie : lignes `raw_ingestions` (idempotent sur `source_id + external_id`) et stats `{fetched,new,skipped,errors}`. Dépend de `RssFetcher` (faraday, feedjira, rss) et `IcsFetcher` (faraday, icalendar). N'appelle jamais l'IA. Kind `press` volontairement non géré. | Générique côté stockage. Manque : respect de `robots.txt`, pas de connecteurs HTML/JSON/sitemap (agenda Grand Nancy, formations…), pas de filtre géographique ni de péremption, dédoublonnage par `external_id` seul (pas titre+date). `IcsFetcher` sans timeout ni gestion d'erreur. |
| `AiEnricher` (`app/services/ai_enricher.rb`, 189 l.) | **Fonctionnel, le plus abouti.** `prompt_for` et `parse_response` purs (prévus pour un batch), `#call(payload, kind:)`. Deux schémas JSON (structured outputs) : `:opportunity` (title, description_md, category parmi 5, dated, expires_at, location, organization, source_url) et `:story` (title, chapo, body_md, happened_on, location, quote, source_url, source_name). Prompts longs, règles anti-verbatim, hiérarchie de repli pour `location`. Dépend d'`AnthropicClient`. | Le schéma Opportunité n'a **ni date de début** (`starts_at`), **ni lien d'inscription** (`cta_button_url`/`cta_button_text`), **ni horaire récurrent** (`schedule_text`), **ni `application_deadline`**, ni contact, alors que ces colonnes existent dans `opportunities`. Une seule `expires_at` (« fin réelle »). Pas de qualification amont (pertinence / hors Grand Nancy) : tout item est enrichi, donc coût IA sur du bruit. Modèle unique pour tout (défaut Sonnet 4.6), pas de tri économique. |
| `StoryDrafter` (`app/services/story_drafter.rb`, 77 l.) | **Fonctionnel.** Entrée : `RawIngestion` ; appelle `AiEnricher` en `:story` ; crée une `Story` inactive (via callback) ; renvoie `Result(status: …)` (`drafted`, `linked_existing`, `validation_failed`, `ai_error`, `already_processed`). Dédoublonne sur `source_url`. Erreur IA → `processed_at` reste nil (réessai). | Hors sujet pour les Opportunités. Sert de modèle : son jumeau **`OpportunityDrafter`** (`app/services/opportunity_drafter.rb`, 71 l.) existe déjà mais ne mappe que `title, description, category, location, organization, source_url, expires_at, raw_payload` + `is_active:false`. Il ignore `starts_at`, `dated`, `cta_*`, `schedule_text`. Le champ `dated` produit par l'IA est jeté. |
| `AnthropicClient` (`app/services/anthropic_client.rb`, 87 l.) | **Fonctionnel, minimal.** Appel synchrone `POST /v1/messages` via faraday, headers `x-api-key` + `anthropic-version 2023-06-01`, timeouts 60/10 s, un retry sur timeout/connexion, erreurs typées (401, 429, autres). `**extra` laisse passer `output_config`, `tools`… Conçu pour accueillir l'API Batch. Pas de gem `anthropic`. | Pas de retry/backoff sur 429 ni 5xx, pas de comptage de coût/tokens (l'usage n'est lu que dans `ai:ping`), pas de plafond d'appels par exécution, pas de test. Sur `veille-auto`, le client est plus complet et testé (`test/services/anthropic_client_test.rb`). |

### Brique annexe : modèles et données

| Élément | État | Manque |
|---|---|---|
| `Source` (`kind` rss/ics/press, `enabled`, `last_run_at`, `last_error`) | Fonctionnel | Pas de fiabilité, de périmètre géographique, de fréquence, de type de contenu cible (opportunité vs histoire) |
| `RawIngestion` (payload JSON, `processed_at`, `error`, `opportunity_id`, `story_id`) | Fonctionnel ; `#draft` renvoie l'Opportunité ou la Story | Pas de statut « écarté / à vérifier » : seulement traité / non traité |

## 3. Branchement

**Isolé : uniquement des tâches rake**, aucun écran, job ni scheduler.

- Aucune route ni contrôleur ne référence `RawIngestion`, `Source` ou les drafters (`config/routes.rb` : namespace `admin` limité à `opportunities` et `stories`).
- Tâches : `rake ai:ping`, `ai:enrich_sample FIXTURE= KIND=`, `ingest:fetch_one NAME=`, `ingest:fetch_all`, `ingest:from_press URL= FAITS= TYPE=opportunity|story [FORCE=1]`, `sources:add`, `sources:list`.
- Le seul lien avec l'admin est indirect : les brouillons (`is_active=false`) apparaissent dans `/admin/opportunities` et `/admin/stories`, où l'éditeur les relit. `from_press` avertit que `FORCE=1` détruit un brouillon déjà retouché.
- `ingest:fetch_all` remplit seulement `raw_ingestions` ; `rake ingest:enrich_pending` (`ingest.rake:131`) boucle ensuite `OpportunityDrafter` sur les raw en attente. Les `Story` ne sont créées que par `ingest:from_press TYPE=story`.

## 4. Périmètre : Belles Histoires ou générique ?

**Générique, avec des trous côté Opportunités.** Le schéma de données, `AiEnricher` (deux modes) et les deux drafters couvrent déjà les deux types. La demande « Belles Histoires seulement » décrit plutôt `veille-belles-histoires`/`veille-auto`, pas `ingestion-ia`. Mais le côté Opportunité est mince : pas de date de début, pas de lien d'inscription, pas d'horaire récurrent, alors que `Opportunity` a `starts_at`, `ends_at`, `application_deadline`, `schedule_text`, `cta_button_text`, `cta_button_url`. Sur `veille-auto`, le périmètre est explicitement « opportunités et belles histoires » (`docs/veille-auto.md`).

## 5. Tests, configuration, documentation

- **Tests : aucun** sur la branche pour ce module. Seules traces : 5 fixtures JSON dans `test/fixtures/raw_ingestions/` (`exemple_rss`, `exemple_ics`, `exemple_tordu`, `exemple_press_opportunity`, `exemple_press_story`), utilisées à la main par `ai:enrich_sample`. `veille-auto` ajoute ~25 fichiers de tests (client, enricher, drafter, runner, robots, connecteurs…).
- **Configuration** : `config/initializers/anthropic.rb` lit `ANTHROPIC_API_KEY` (aucune valeur par défaut) et `ANTHROPIC_MODEL` (défaut `claude-sonnet-4-6`). Aucun `.env.example` ni mention dans le README. Le client lève `AuthenticationError` si la clé est vide. Je n'ai pas cherché de valeur réelle de clé dans l'environnement.
- **Documentation** : aucune pour ce module sur `ingestion-ia` (commentaires de tête dans les classes uniquement). `veille-auto` a `docs/veille.md` et `docs/veille-auto.md` (chaîne, sources, Heroku Scheduler, variables `ANTHROPIC_API_KEY`, `ENGAGEMENT_API_KEY`).
- **Gems** : `faraday`, `feedjira`, `rss`, `icalendar`, `httparty`, `nokogiri` ; pas de gem Anthropic.
- **Hygiène** : `ingestion-ia` embarque des commits étrangers (prototype carte 3D, icônes, PDF, `public/geo/*.geojson`) ; ne pas la fusionner telle quelle.

## 6. Recommandation (pour décision, rien n'a été fait)

Ne pas étendre `ingestion-ia`. Partir de `veille-auto`, qui contient déjà les Opportunités, l'admin, les tests et la doc, puis vérifier avec `git diff main...veille-auto` ce qui reste à fusionner dans `main`. `ingestion-ia` n'a de valeur que comme historique (prompts d'`AiEnricher`, mode `from_press`), et ces éléments sont déjà repris sur `veille-auto` (`app/services/veille/ai_enricher.rb`, `story_drafter.rb`).

## Fichiers concernés (branche `ingestion-ia`)

Services
- `app/services/raw_ingester.rb`
- `app/services/ai_enricher.rb`
- `app/services/story_drafter.rb`
- `app/services/opportunity_drafter.rb`
- `app/services/anthropic_client.rb`
- `app/services/rss_fetcher.rb`, `app/services/ics_fetcher.rb`

Modèles et base
- `app/models/raw_ingestion.rb`, `app/models/source.rb`
- `db/migrate/20260618110000_create_sources_and_raw_ingestions.rb`
- `db/migrate/20260618120000_add_story_to_raw_ingestions.rb`
- `db/migrate/20260114155559_add_source_fields_to_opportunities.rb`

Configuration et tâches
- `config/initializers/anthropic.rb`
- `lib/tasks/ai.rake`, `lib/tasks/ingest.rake`, `lib/tasks/sources.rake`

Tests (fixtures uniquement)
- `test/fixtures/raw_ingestions/exemple_{rss,ics,tordu,press_opportunity,press_story}.json`

Branche successeur `veille-auto` (à auditer ensuite)
- `app/services/veille/*` (runner, connectors/, ai_enricher, qualifier, drafter, story_drafter, validation, robots_policy…)
- `app/controllers/admin/veille/*`, `app/views/admin/veille/*`, `app/models/veille/*`
- `lib/tasks/veille.rake`, `docs/veille.md`, `docs/veille-auto.md`, `test/services/veille/*`
