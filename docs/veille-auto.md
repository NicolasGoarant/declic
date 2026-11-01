# Veille automatique (opportunités et belles histoires)

> **Statut (01/11/2026) : en production** sur `www.declic.site` (app EU `declic-nancy-paris-eu`, v21, commit 4bf7dd7). Les migrations sont passées. L'écran `/admin/veille` est derrière le mot de passe admin. IA active (`ANTHROPIC_API_KEY` posée le 01/11, plafond 15 $/mois). Scheduler Heroku ajouté ; la tâche `rake veille:quotidien` (05:00 UTC) est à créer à la main dans son tableau de bord. `veille_sources` est vide : les sources du quotidien sont dans le code. La presse reste en lecture manuelle sur `/admin/veille/presse`.

Branche `veille-auto` (depuis `main` + `veille-belles-histoires`). Écran : `/admin/veille`. Rien n'est publié sans clic « Valider », et le brouillon créé est inactif.

## Chaîne
`rake veille:quotidien` → `Veille::Runner` → connecteurs (`app/services/veille/connectors/`) → `RawIngester` (dédoublonnage URL ou titre normalisé + date ; hors périmètre et passé écartés) → `AiEnricher` (Haiku, 30 éléments max par exécution) → **étape « rédiger »** : `Redaction::Brouillon` (Sonnet, belles histoires, ~120 mots, 30 max, reprenable : 3 essais par candidat, arrêt après 3 erreurs d'affilée) → `Redaction::Controles` (horaires, appels à l'action, contacts, citations et chiffres étrangers à la source, copie) → relecture admin (récit éditable, accord de la personne) → `Validation` (Opportunity ou Story inactive, seul chemin). Une `Story` issue de la veille ne se met pas en ligne sans l'accord de la personne.

Chaque appel IA est journalisé (`veille_appels_ia`) ; **plafond mensuel 15 $** (`VEILLE_BUDGET_USD_MOIS`), vérifié avant chaque envoi. Détail : `docs/veille.md`.

## Sources (état au 13/10/2026)
| Source | État | Note |
|---|---|---|
| 1 JeVeuxAider / API Engagement | **Retirée de `QUOTIDIEN`** (31/10) : piste abandonnée | Connecteur conservé, non lancé. |
| 2 Agenda Grand Nancy | répond | JSON `agenda-integration.grandnancy.eu/api/vdn/events` (celui de nancy.fr/agenda). Rubriques gardées : Conférence-Rencontre, Citoyenneté, Festival, Animation. |
| 3 Formation | **Retirée du pipeline** (31/10) : le catalogue UIMM Lorraine noyait la file, une fiche par diplôme. formation.grandest.fr non branchée (appli Angular, base d'API inconnue) | |
| 4 Transentreprise | RSS `/rss/offre` répond ; 0 offre Nancy cette semaine | texte réduit à l'accroche |
| 5 La Gazette France | **Retirée de `QUOTIDIEN`** (31/10) : contenu de presse lu et envoyé à l'IA sans geste humain | Connecteur conservé, non lancé. |
| 6 Presse | **Veille manuelle** (31/10) : les CGU de L'Est Républicain s'opposent à la fouille de textes | `/admin/veille/presse` lit les flux à l'affichage : titre et lien seulement, ni stockage, ni chapeau, ni IA. « Retenir » crée un candidat que les passes automatiques ignorent (`Candidate.hors_presse`). |

`Veille::Http` lit le robots.txt de chaque hôte avant toute requête (Crawl-delay respecté, 1 s mini entre appels).

## Heroku Scheduler
- `rake veille:quotidien` (daily) : agenda et Transentreprise.
- Variables : `ANTHROPIC_API_KEY`, `VEILLE_BUDGET_USD_MOIS` (facultative, 15 par défaut).
- Rattrapage des récits : `rake veille:rediger` (`LIMITE=n`). Dépense d'un mois : `rake veille:cout[AAAA-MM]`.
- Import initial : placer `docs/declic-reperage-v1-2026-10-13.xlsx` puis `rake veille:import_xlsx` (statut « à vérifier », sans IA).

## Idées à reprendre plus tard (non implémentées)
Issues de la branche `feat/ingest-sources` (un commit du 22/09/2025, écartée le 28/10/2026 : publication sans relecture, pas de `robots.txt`, pas de tests ; voir `docs/audit-feat-ingest-sources-2026-10-28.md` sur `main`). On ne reprend **pas le code** : on réécrit chaque idée comme connecteur `Veille::Connectors::Base`, qui passe par `Veille::Http` (robots.txt, 1 s mini) et rend des `Veille::Item` ; tout finit en brouillon dans `/admin/veille`. Le code d'origine se lit encore sur `origin/feat/ingest-sources` (`app/services/fetchers/`, `app/services/support/french_date_parser.rb`) : ne pas supprimer la branche tant que ces trois points ne sont pas traités.

1. **Connecteur JSON-LD `Event` générique** (le plus réutilisable). Lit les objets `Event` JSON-LD d'une page de liste, puis des pages détail (plafond de liens à fixer, par exemple 30). Une sous-classe par site fournit l'URL et le filtre. Complète `PageFetcher`, qui ne lit le JSON-LD que d'une seule page d'article. Origine à ajouter à `Candidate::ORIGINS`.
2. **Sources CCI Grand Nancy et Lorr'Up** (catégorie « entreprendre », aujourd'hui couverte par Transentreprise seulement). Pages visées dans l'ancienne branche : `nancy.cci.fr/evenements`, `nancy.cci.fr/formations`, `lorr-up.fr/evenements/`, `lorr-up.fr/actualites/`. À faire avant tout code : vérifier que les URL répondent encore, lire le `robots.txt` et les CGU de chaque site, et regarder si le JSON-LD de l'idée 1 suffit (les anciens scrapers par regex et sélecteurs HTML sont fragiles). Lorr'Up « Actualités » relève plutôt des belles histoires que des opportunités : le type se décide à l'enrichissement, pas à la collecte.
3. **Analyseur de dates françaises** (« jeudi 16 octobre 2025 de 09h30 à 11h30 »). Utile seulement si une source n'expose que du texte libre ; sinon on garde les dates ISO. À écrire avec ses tests, dans `Veille::Text` ou un module voisin, et à ne jamais laisser deviner une date : illisible → `nil`.

Ce qu'on ne reprend pas : le pipeline Sidekiq-cron (pas de worker ni de Redis sur Heroku, le Scheduler suffit), `Ingest::Upserter` (création directe d'`Opportunity` active), les `rescue` muets.
