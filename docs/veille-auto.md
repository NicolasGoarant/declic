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
