# Audit de la branche `feat/ingest-sources` — 28/10/2026

Audit en lecture seule : `git fetch origin feat/ingest-sources` (met à jour `FETCH_HEAD` seulement), puis `git show` / `git diff` / `git grep` sur `origin/feat/ingest-sources`. Aucun checkout, aucun code modifié, rien fusionné. Fait suite à `audit-ingestion-ia-2026-10-28.md` et `audit-veille-auto-2026-10-28.md`.

## Résumé

1. Branche gelée depuis le **22/09/2025** (13 mois) : un seul commit propre (`1113b30`, « diverses data »), 440 commits de retard sur `main`, 397 sur `veille-auto`. La ref locale et `origin` pointent sur le même commit.
2. C'est une **autre approche**, antérieure et sans lien de code avec `veille-auto` : fetchers sans IA, pipeline Sidekiq toutes les 30 min, création **directe et active** d'`Opportunity`. Aucune des briques `RawIngester` / `AiEnricher` / `StoryDrafter` / `AnthropicClient`.
3. Elle contient un besoin que `veille-auto` ne couvre pas : les **sources entrepreneuriat CCI Grand Nancy et Lorr'Up**, et un **lecteur JSON-LD d'événements** générique. Rien d'autre d'utile.
4. Ni tests, ni doc ; code non conforme aux règles de `veille-auto` (pas de `robots.txt`, erreurs avalées, publication automatique).
5. Avis : **(b) minimal** — fusionner `veille-auto` seule, ne pas fusionner cette branche, et reprendre plus tard *l'idée* de trois sources sous forme de connecteurs `Veille::Connectors`. Rien d'urgent n'est perdu à la laisser de côté.

## 1. Situation de la branche

| Mesure | Valeur |
|---|---|
| Tête | `1113b30`, 22/09/2025 20:01, « diverses data » (auteur : vous) |
| Base commune avec `main` et `veille-auto` | `9ef0b0b`, 22/09/2025 06:12 (« checkpoint avant uniformisation du ton ») |
| Écart avec `main` | +1 / −440 |
| Écart avec `veille-auto` | +1 / −397 |
| Écart avec `ingestion-ia` | +1 / −321 |
| Présence | locale et `origin`, même commit |
| Activité | abandonnée (aucun commit depuis 13 mois) |

Le commit unique mélange le travail d'ingestion à des changements sans rapport : pages légales/FAQ/presse, navbar, carte (`_map.html.erb`), modèle `Opportunity`, `Gemfile`. Ces changements sont périmés par les 440 commits de `main`.

## 2. Contenu et approche

Approche « scraping sans IA » :

```
Source (kind: ics | rss | jsonld)
  → Sources::SweepJob (Sidekiq-cron, toutes les 30 min, file `ingest`)
  → Sources::FetchJob → Fetchers::{Ics,Rss,JsonldEvents,DeepJsonld,CciNancy,Lorrup}
  → Ingest::Normalizer (score par mots-clés, champs par défaut : catégorie « entreprendre »)
  → Ingest::Upserter → Opportunity (is_active = true)
```

| Brique | Rôle | Équivalent dans `veille-auto` |
|---|---|---|
| `Fetchers::JsonldEventsFetcher` (45 l.) | Lit les `Event` JSON-LD d'une page liste | Aucun pour des listes (`PageFetcher` lit le JSON-LD d'**une** page d'article) |
| `Fetchers::DeepJsonldFetcher` (74 l.) | Suit jusqu'à 30 liens internes et lit leurs JSON-LD | Aucun |
| `Fetchers::CciNancyFetcher` (79 l.) | Scrape `nancy.cci.fr` (≤ 25 liens), date par regex | **Aucun** : CCI absente de `veille-auto` |
| `Fetchers::LorrupFetcher` (85 l.) | Scrape `lorr-up.fr` (≤ 60 liens), filtre atelier/webinaire/réunion | **Aucun** : Lorr'Up absente de `veille-auto` |
| `Fetchers::{Ics,Rss}Fetcher` | ICS / RSS | `RssFetcher`/`IcsFetcher` de `ingestion-ia`, `Connectors::Presse` (RSS) sur `veille-auto` |
| `Support::FrenchDateParser` (38 l.) | « jeudi 16 octobre 2025 de 09h30 à 11h30 » → date | Aucun (les connecteurs lisent des dates ISO) |
| `Ingest::Normalizer` / `Ingest::Upserter` | Valeurs par défaut, score regex, dédoublonnage URL ou titre ± 1 jour, création active | `Veille::RawIngester`, `AiEnricher`, `Validation` (en mieux) |
| `Sources::SweepJob` / `FetchJob`, `config/sidekiq.yml` | Planification Sidekiq | `rake veille:quotidien` + Heroku Scheduler |
| `db/seeds/sources.rb` | 4 sources : CCI Événements, CCI Formations, Lorr'Up Événements, Lorr'Up Actualités | — |

Gems ajoutées : `sidekiq`, `sidekiq-cron`, absentes de `main` et de `veille-auto` (`friendly_id` y est déjà).

## 3. Comparaison avec `veille-auto`

| Critère | `feat/ingest-sources` | `veille-auto` |
|---|---|---|
| Classification Opportunité / Belle Histoire | Non (tout est Opportunité « entreprendre ») | Oui (règle éditoriale, Haiku) |
| IA | Aucune | Haiku (tri), Sonnet (rédaction) |
| Relecture humaine | Aucune : `is_active = true` à l'import | Obligatoire : brouillon inactif après « Valider » |
| Respect de `robots.txt` | Non (`URI.open`, UA « DeclicBot/1.0 ») | Oui (`Veille::Http`, `RobotsPolicy`, 1 s mini entre appels) |
| Zone géographique | Non filtrée | Grand Nancy (`GrandNancy.inclut?`) |
| Erreurs | `rescue` muets, retour `[]` | Statuts `ok/refuse/erreur/inactive`, journal, coût |
| Exécution | Sidekiq-cron (pas de worker dans le `Procfile`) | rake + Heroku Scheduler |
| Tests, doc | Aucun, aucune | 21 fichiers de tests, 2 docs |
| Sources entrepreneuriat | **CCI Grand Nancy, Lorr'Up** | Transentreprise (offres de cession) seulement |
| Méthode de collecte | Scrape de pages + JSON-LD événements | API JSON, sitemap, RSS, pages de rubrique |

Ce que `feat/ingest-sources` couvre en plus : deux sources (CCI, Lorr'Up) pertinentes pour la catégorie « entreprendre », le JSON-LD `Event` comme méthode générique (utile pour tout site d'agenda sans API), et l'analyse de dates françaises en texte libre. Ce qu'elle ne couvre pas et que `veille-auto` couvre : tout le reste.

## 4. Tests, documentation, état

- **Tests** : aucun fichier de test ou de fixture dans le diff. **Doc** : aucune.
- **Abandonnée** : dernier commit le 22/09/2025, avant le chantier IA (juin 2026 pour `ingestion-ia`, septembre-octobre pour `veille-auto`).
- **Non exécutée** : je n'ai pas testé les fetchers. Rien ne garantit que `nancy.cci.fr/evenements` et `lorr-up.fr/evenements/` répondent encore, ni que leur structure HTML correspond aux sélecteurs.
- **Risques si on la reprenait telle quelle** : publication sans relecture (contraire à la règle « rien n'est publié sans clic »), pas de `robots.txt`, `rescue` qui masque les pannes, un `Normalizer` qui accepte d'office tout ce qui a un titre et une date, et une dépendance Sidekiq + Redis non provisionnée.

## 5. Avis

**(b), version minimale : fusionner `veille-auto` seule ; ne rien récupérer maintenant de cette branche ; noter trois idées à reprendre ensuite si l'on veut couvrir l'entrepreneuriat.**

Raisons :

1. La branche n'apporte aucun code réutilisable tel quel : tout contournerait les garde-fous de `veille-auto` (relecture, `robots.txt`, zone, journal).
2. Il n'y a rien à « perdre » dans une fusion de `veille-auto` : `feat/ingest-sources` est une branche parallèle qui part d'un commit antérieur et n'est pas un ancêtre de `veille-auto`. Elle reste intacte sur `origin` si vous voulez y revenir.
3. Les idées à garder, à reprendre plus tard comme connecteurs `Veille::Connectors::Base` (donc via `Veille::Http`) et non comme code importé :
   - un connecteur **JSON-LD `Event`** générique (liste + pages détail), le plus réutilisable ;
   - les sources **CCI Grand Nancy** et **Lorr'Up**, à revérifier (URL, `robots.txt`, CGU) avant tout ;
   - le **parseur de dates françaises**, utile seulement si une source n'expose que du texte libre.
4. À faire après la fusion, pas avant : ne rien supprimer sur `origin` tant que ces trois idées ne sont pas notées ailleurs (par exemple dans `docs/veille-auto.md`).

## Fichiers concernés (branche `origin/feat/ingest-sources`)

Ingestion
- `app/jobs/sources/fetch_job.rb`, `app/jobs/sources/sweep_job.rb`
- `app/services/fetchers/{cci_nancy,deep_jsonld,ics,jsonld_events,lorrup,rss}_fetcher.rb`
- `app/services/ingest/{normalizer,upserter}.rb`
- `app/services/support/french_date_parser.rb`
- `app/services/ingestors.rb`, `app/services/{rss,ics}_fetcher.rb` (hérités)
- `app/models/source.rb`, `app/models/raw_ingestion.rb`

Base et configuration
- `db/migrate/20250922165100_add_missing_columns_to_sources.rb`, `db/migrate/…2170357_add_missing_columns_to_opportunities.rb`
- `db/seeds/sources.rb` (CCI × 2, Lorr'Up × 2), `config/sidekiq.yml`, `Gemfile` (`sidekiq`, `sidekiq-cron`)

Sans rapport avec l'ingestion (même commit, périmés)
- `app/views/pages/{confidentialite,faq,home,legal,presse}.html.erb`, `app/views/shared/_navbar.html.erb`, `app/views/_map.html.erb`, `app/views/{opportunities,stories}/*`, `app/models/opportunity.rb`, `app/controllers/opportunities_controller.rb`, `config/initializers/geocoder.rb`
