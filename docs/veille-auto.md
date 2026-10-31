# Veille automatique (opportunités et belles histoires)

Branche `veille-auto` (depuis `main` + `veille-belles-histoires`). Écran : `/admin/veille`. Rien n'est publié sans clic « Valider », et le brouillon créé est inactif.

## Chaîne
`rake veille:quotidien` / `veille:hebdomadaire` → `Veille::Runner` → connecteurs (`app/services/veille/connectors/`) → `RawIngester` (dédoublonnage URL ou titre normalisé + date ; hors Grand Nancy et passé écartés) → `AiEnricher` (Haiku, 30 éléments max par exécution, coût estimé dans les logs) → `StoryDrafter` (belles histoires, ~120 mots, source + « Accord de la personne : à obtenir ») → relecture admin → `Validation` (Opportunity ou Story inactive).

## Sources (état au 13/10/2026)
| Source | État | Note |
|---|---|---|
| 1 JeVeuxAider / API Engagement | **clé requise** : `ENGAGEMENT_API_KEY` (401 sans) | `EngagementApi` existant, 15 km autour de Nancy, régime « Ouvert toute l'année » sans date. Non testée en réel. |
| 2 Agenda Grand Nancy | répond | JSON `agenda-integration.grandnancy.eu/api/vdn/events` (celui de nancy.fr/agenda). Rubriques gardées : Conférence-Rencontre, Citoyenneté, Festival, Animation. |
| 3 Formation | UIMM Lorraine répond (sitemap + pages) ; **formation.grandest.fr non branchée** (appli Angular, base d'API inconnue) | |
| 4 Transentreprise | RSS `/rss/offre` répond ; 0 offre Nancy cette semaine | texte réduit à l'accroche |
| 5 La Gazette France | répond (rubrique /meurthe-et-moselle) | |
| 6 Presse | L'Est Républicain : flux ok ; **France 3 : refusé par robots.txt** | flux RSS seulement, aucun article visité ; alertes e-mail non implémentées |

`Veille::Http` lit le robots.txt de chaque hôte avant toute requête (Crawl-delay respecté, 1 s mini entre appels).

## Heroku Scheduler
- `rake veille:quotidien` (daily). `rake veille:hebdomadaire` (daily aussi : ne travaille que le lundi, `FORCE=1` pour forcer).
- Variables : `ANTHROPIC_API_KEY`, `ENGAGEMENT_API_KEY`.
- Import initial : placer `docs/declic-reperage-v1-2026-10-13.xlsx` puis `rake veille:import_xlsx` (statut « à vérifier », sans IA).

## Idées à reprendre plus tard (non implémentées)
Issues de la branche `feat/ingest-sources` (un commit du 22/09/2025, écartée le 28/10/2026 : publication sans relecture, pas de `robots.txt`, pas de tests ; voir `docs/audit-feat-ingest-sources-2026-10-28.md` sur `main`). On ne reprend **pas le code** : on réécrit chaque idée comme connecteur `Veille::Connectors::Base`, qui passe par `Veille::Http` (robots.txt, 1 s mini) et rend des `Veille::Item` ; tout finit en brouillon dans `/admin/veille`. Le code d'origine se lit encore sur `origin/feat/ingest-sources` (`app/services/fetchers/`, `app/services/support/french_date_parser.rb`) : ne pas supprimer la branche tant que ces trois points ne sont pas traités.

1. **Connecteur JSON-LD `Event` générique** (le plus réutilisable). Lit les objets `Event` JSON-LD d'une page de liste, puis des pages détail (plafond de liens à fixer, par exemple 30). Une sous-classe par site fournit l'URL et le filtre. Complète `PageFetcher`, qui ne lit le JSON-LD que d'une seule page d'article. Origine à ajouter à `Candidate::ORIGINS`.
2. **Sources CCI Grand Nancy et Lorr'Up** (catégorie « entreprendre », aujourd'hui couverte par Transentreprise seulement). Pages visées dans l'ancienne branche : `nancy.cci.fr/evenements`, `nancy.cci.fr/formations`, `lorr-up.fr/evenements/`, `lorr-up.fr/actualites/`. À faire avant tout code : vérifier que les URL répondent encore, lire le `robots.txt` et les CGU de chaque site, et regarder si le JSON-LD de l'idée 1 suffit (les anciens scrapers par regex et sélecteurs HTML sont fragiles). Lorr'Up « Actualités » relève plutôt des belles histoires que des opportunités : le type se décide à l'enrichissement, pas à la collecte.
3. **Analyseur de dates françaises** (« jeudi 16 octobre 2025 de 09h30 à 11h30 »). Utile seulement si une source n'expose que du texte libre ; sinon on garde les dates ISO. À écrire avec ses tests, dans `Veille::Text` ou un module voisin, et à ne jamais laisser deviner une date : illisible → `nil`.

Ce qu'on ne reprend pas : le pipeline Sidekiq-cron (pas de worker ni de Redis sur Heroku, le Scheduler suffit), `Ingest::Upserter` (création directe d'`Opportunity` active), les `rescue` muets.
