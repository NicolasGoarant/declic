# Veille « Belles Histoires »

Outil interne de repérage qui alimente la rubrique Belles Histoires : des
portraits repérés dans la presse locale et les publications de collectivités,
**réécrits intégralement**, avec un lien vers la source d'origine.

Tout vit sous `/admin/veille`, derrière l'authentification admin du projet.
Rien n'est exposé publiquement.

---

## La règle sur `full_text`

**`full_text` est un tampon de travail, et rien de plus. Il est effacé dès
que la fiche publiée est créée.**

Déclic évite de constituer une base dérivée d'articles de presse. On conserve
la fiche réécrite et le lien vers la source ; on ne conserve pas l'article.

La règle est appliquée par un callback, pas par une discipline d'usage :

```ruby
# app/models/story.rb
after_create :purge_veille_candidate_full_text
```

Il se déclenche à la création de **toute** `Story` rattachée à un candidat,
quel que soit le chemin emprunté — interface admin, console, script, import
futur. `update_columns` est utilisé pour ne pas relancer les validations du
candidat depuis un `after_create`.

Trois conséquences à garder en tête :

- Après publication, le bouton « Rédiger » d'un candidat lève une
  `ArgumentError` : il n'y a plus de texte. C'est voulu. Pour reprendre une
  fiche, on recolle le texte.
- Tout le reste du candidat survit : url, titre, chapeau, score, motif. Ce
  sont des métadonnées, pas l'œuvre.
- **Ne transformez jamais ce callback en archivage.** Si un jour vous avez
  besoin de conserver l'article, c'est une décision juridique, pas technique.

Couverture : `test/models/story_test.rb`.

---

## Le flux, de bout en bout

```
connecteurs (rake veille:quotidien)                     rake veille:import (liste d'URL)
        |                                                      |
        v                                                      v
   RawIngester : dédoublonne, écarte hors périmètre / passé    PageFetcher
        \______________________  ________________________________/
                               v
                  Veille::Candidate (status: pending)
                               |
                               |  Veille::AiEnricher (Haiku, 30 par exécution)
                               |  type (opportunité / belle histoire), catégorie,
                               |  commune, date ou régime, résumé reformulé
                               v
              belle histoire ?  --- non ---> opportunité : relecture, « Valider »
                               |
                               |  Veille::Redaction::Brouillon (Sonnet)
                               |  étape séparée du Runner : « rediger »
                               |  (ou bouton « Rédiger » de l'écran, avec texte collé)
                               v
        Redaction::Controles : horaires, appels à l'action, contacts,
        citations / chiffres absents de la source, copie
                               |
        draft_status : redige | a_verifier (bloquant) | a_reprendre (incident API)
                               |
          /admin/veille/:id : récit éditable, contrôles, manques,
          case « accord obtenu », coût IA du candidat
                               |
                      « Valider » (Veille::Validation, seul chemin)
                               v
                  Story (is_active: false) --> full_text = nil
                               |
        mise en ligne depuis /admin/stories : refusée sans l'accord de la personne
```

Chaque appel à l'API est inscrit dans le journal `veille_appels_ia` ; le plafond
mensuel (15 $ par défaut) est vérifié avant chaque envoi.

---

## Modèles

Tout est préfixé et namespacé sous `Veille`, sans aucune collision avec les
tables `sources` / `raw_ingestions` ni les classes de la branche
`ingestion-ia`.

### `Veille::Source` — table `veille_sources`

Registre des publications surveillées. Aucun collecteur n'y est branché : la
table sert de référentiel et de rattachement.

| Colonne | Détail |
|---|---|
| `name` | obligatoire, unique |
| `kind` | `presse`, `magazine_municipal`, `media_public` |
| `url` | obligatoire |
| `active` | booléen, `true` par défaut |
| `last_collected_at` | inutilisé pour l'instant, prévu pour un futur collecteur |

### `Veille::Candidate` — table `veille_candidates`

| Colonne | Détail |
|---|---|
| `veille_source_id` | facultatif ; `nullify` à la suppression de la source |
| `title`, `excerpt`, `published_on` | extraits par le connecteur ou `PageFetcher` |
| `url` | obligatoire, **unique et indexée** — c'est la clé de dédoublonnage |
| `origin`, `reliability` | source de la collecte et fiabilité (haute / moyenne / basse) |
| `item_type` | `opportunite` ou `belle_histoire`, posé par `AiEnricher` (règle éditoriale) |
| `declic_category`, `commune`, `starts_on`, `ends_on`, `schedule_text` | proposés par `AiEnricher` |
| `summary` | résumé reformulé, deux phrases |
| `full_text` | le tampon. Voir la règle ci-dessus |
| `score`, `reason` | confiance de l'IA (0-100, **indexé**) et son motif |
| `status` | `pending` / `a_verifier` -> `retenu` / `ecarte` -> `publie`. **Indexé** |
| `draft_body` | récit rédigé, avec les mentions « Source » et « Accord de la personne » |
| `draft_status` | `aucun`, `redige`, `a_reprendre` (incident d'API), `a_verifier` (contrôle bloquant) |
| `draft_manques`, `draft_controles` | informations absentes de la source ; résultat de `Redaction::Controles` |
| `draft_attempts` | essais de la veille automatique (3 au plus) |
| `accord_obtenu_at` | accord de la personne racontée |

Scopes : `file_de_tri` (les `pending`, meilleur score d'abord), `a_enrichir`, `a_rediger`.
Il n'y a plus de colonne `category` (passe « Qualifier » retirée) : le type est `item_type`.

### `Veille::AppelIa` — table `veille_appels_ia`

Une ligne par appel à l'API : `candidate_id` (conservé, mis à `nil`, si le candidat est supprimé),
`passe` (`enrichissement` / `redaction`), `modele`, `statut` (`ok`, `erreur_api`, `illisible`,
`refuse_controle`, `plafond`), tokens, `cout_usd` estimé (`Veille::Cout`), durée. Écrite par
`AiPass#run`, jamais à la main.

### `Story`

Le modèle de la rubrique **existait déjà** (`/stories`, `/admin/stories`) et
portait déjà `source_url` et `source_name`. Ont été ajoutés `veille_candidate_id` et
`accord_obtenu_at`. **Une fiche issue de la veille ne peut pas être mise en ligne tant que
l'accord de la personne n'est pas obtenu** (contrôlé à la création et à la bascule en ligne ;
les fiches saisies à la main et les fiches déjà publiées ne sont pas concernées). La case se
coche sur l'écran de la veille, ou dans le formulaire d'édition de la fiche. Supprimer un candidat ne détruit pas la fiche publiée : `nullify`.

---

## Services

### `AnthropicClient`

Porté depuis `ingestion-ia`, avec trois correctifs :

- `Faraday::ConnectionFailed` / `TimeoutError` -> `AnthropicClient::ConnectionError` ;
  `JSON::ParserError` sur un corps 2xx -> `AnthropicClient::MalformedResponseError`.
  Les deux héritent d'`AnthropicClient::Error`. Auparavant elles fuyaient
  brutes et échappaient aux `rescue` en aval.
- `timeout:` paramétrable, **20 s par défaut**.
- `retries:` paramétrable, 1 par défaut, **0 sur le chemin web**.

Clé dans `ENV['ANTHROPIC_API_KEY']`.

### `Veille::AiPass`

Base commune. Deux méthodes de classe **pures**, donc testables sans réseau :
`prompt_for` construit les paramètres, `parse_response` rend le hash.

Le JSON strict est obtenu par le format structuré
(`output_config.format.type = "json_schema"`). `parse_response` garde en plus
un repêchage par expression régulière au cas où le modèle enroberait sa
réponse de balises Markdown.

### `Veille::AiEnricher` — classement

`claude-haiku-4-5-20251001`. Pour un élément brut : type (opportunité ou belle histoire, selon
la règle éditoriale), catégorie, commune, date ou régime, résumé reformulé en
deux phrases (au plus 15 mots consécutifs repris de la source). Écarte ce qui est hors ligne, hors
périmètre (`Veille::Territoire` : Grand Est pour une histoire, Meurthe-et-Moselle pour une
opportunité) ou passé. Les sources officielles (agenda, Transentreprise) sont
toujours des opportunités.

### `Veille::Redaction::Brouillon` — rédaction du récit

`claude-sonnet-5`. Remplace l'ancien `StoryDrafter` (automatique) et l'ancien `Drafter` (manuel).
Un seul prompt qui porte la règle éditoriale : récit d'environ 120 mots, **ni horaires ni appel à
l'action**, reformulation intégrale, rien d'inventé, `champs_manquants` plutôt que de combler par
déduction. Rend `{ brouillon, personne, champs_manquants }`.

- **Automatique** (`Runner#rediger`, ou `rake veille:rediger`) : à partir du titre, du résumé et du
  chapeau, jamais du texte intégral.
- **Manuel** (bouton « Rédiger » de l'écran, `profil: :web`) : à partir du texte collé, tronqué à
  12 000 caractères.

Le code, pas le modèle, ajoute « Source : … — URL » et « Accord de la personne : à obtenir »
(ou « obtenu le … »). Le brouillon est enregistré dans `draft_body` avec ses manques, le résultat
des contrôles et un statut ; il ne crée aucune fiche.

### `Veille::Redaction::Controles` — la règle, vérifiée en code

Fonction pure. **Bloquants** : horaires et récurrences (« tous les mardis »), appels à l'action,
contacts (URL, e-mail, téléphone), citations et chiffres absents de la source, copie de plus de
15 mots d'affilée. **Avertissements** : longueur hors de 90 à 160 mots, champs manquants. Un
bloquant met le brouillon « à vérifier » : `Validation` le refuse tant qu'il n'est pas corrigé
(l'écran relance les contrôles à chaque enregistrement).

### `Veille::Plafond` et le journal

Budget mensuel d'après `veille_appels_ia`, réglable par `VEILLE_BUDGET_MENSUEL` (15 $ par
défaut). Atteint, plus aucun appel ne part : `Veille::Plafond::Depasse`, journalisé, et le
`Runner` s'arrête. `rake veille:cout[AAAA-MM]` donne l'état d'un mois.

### `Veille::PageFetcher`

Nokogiri + Net::HTTP, aucune gem ajoutée. Extraction par ordre de priorité :

| Champ | Ordre |
|---|---|
| titre | `og:title` -> `twitter:title` -> JSON-LD `headline` -> `<title>` |
| chapeau | `og:description` -> `twitter:description` -> JSON-LD `description` -> `meta[name=description]` |
| date | `article:published_time` -> JSON-LD `datePublished` -> `meta[name=date]` -> `<time datetime>` |

Une date vague ou illisible devient `nil` plutôt qu'une valeur devinée.
`.extract` est pure et se teste sur du HTML brut.

Garde-fous : 3 redirections au plus, 10 s de timeout, 2 Mo lus au plus,
contenu non-HTML rejeté.

---

## Le budget de temps

Aucun worker dyno sur ce projet : **la rédaction demandée depuis l'écran se fait dans la
requête web, en synchrone**. Le timeout Heroku est de 30 secondes.

| | `open_timeout` | `timeout` | `retries` | pire cas |
|---|---|---|---|---|
| `Redaction::Brouillon`, profil `:web` (écran) | 5 s | 22 s | **0** | **27 s** |
| `Redaction::Brouillon`, profil `:lot` (rake) | 5 s | 40 s | 1 | hors contrainte |
| `Veille::AiEnricher` (rake) | 5 s | 30 s | 1 | hors contrainte |

`retries: 0` sur le profil web n'est pas un détail : un seul retour en arrière doublerait le
temps de réponse et ferait sauter les 30 secondes. Le plafond de 12 000 caractères sur le texte
collé sert le même objectif, et borne le coût par appel ; la troncature est journalisée. Un test
vérifie que 5 + 22 reste sous 30.

---

## Utilisation

### Importer une liste d'URL

Un fichier texte, une URL par ligne. Les lignes vides et celles commençant
par `#` sont ignorées, les doublons aussi.

```
# repérages du 5 septembre
https://www.estrepublicain.fr/…/le-jardin-partage-de-laxou
https://nancy.fr/actualites/…
```

```bash
bin/rails "veille:import[reperages.txt]"
```

Pour chaque URL : récupération de la page, extraction des métadonnées, création du candidat.
**Une seconde entre deux requêtes**, et un User-Agent qui identifie Déclic :

```
DeclicVeille/1.0 (+https://declic.site)
```

Le classement (opportunité ou belle histoire) et la rédaction se font ensuite, à la prochaine
`rake veille:quotidien`.

### Rattrapage et dépense

```bash
bin/rails veille:rediger            # rédige les récits en attente (LIMITE=n pour borner)
bin/rails "veille:cout[2026-11]"    # dépense du mois d'après le journal (mois courant par défaut)
```

### Relire, corriger, valider

`/admin/veille` — la file des candidats. Une opportunité se valide d'un clic. Une belle histoire
renvoie vers son écran (`Relire le récit →`), à deux colonnes :

- À gauche, la source, le classement, le résumé reformulé, et l'historique des appels IA du
  candidat avec leur coût.
- À droite, la zone (facultative) où coller le texte de l'article, puis le **récit** : modifiable,
  avec ses points bloquants, les informations manquantes en jaune, et la case **accord de la
  personne obtenu**.
- **Rédiger** (ou **Rédiger à nouveau**) appelle Sonnet ; **Enregistrer et recontrôler** relance les
  contrôles sur le texte corrigé ; **Valider** crée la fiche hors ligne.

**Valider** (`Veille::Validation`) est le seul chemin vers une `Story` : brouillon inactif, lien vers
la source, `full_text` effacé, date d'accord reportée. Elle refuse un récit aux contrôles bloquants.
La mise en ligne se fait ensuite depuis `/admin/stories`, et n'aboutit qu'avec l'accord obtenu.

### Sources

`/admin/veille/sources` — CRUD minimal. Supprimer une source conserve ses
candidats et les détache simplement.

---

## Configuration

| Variable | Rôle |
|---|---|
| `ANTHROPIC_API_KEY` | obligatoire pour le classement et la rédaction |
| `VEILLE_BUDGET_MENSUEL` | plafond mensuel de l'API, en dollars (15 par défaut) |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | authentification admin (HTTP Basic) |
| `ADMIN_SANS_MOT_DE_PASSE` | `1` : supprime l'authentification sur `/admin/*` **en développement uniquement** (sans effet en test et en production). Réservée au `.env` local ; redémarrer le serveur pour la prendre en compte |

`ANTHROPIC_MODEL` n'est **pas** utilisé par la veille : chaque passe choisit
son modèle explicitement.

---

## Tests

```bash
bin/rails test
```

Tous les appels API sont bouchonnés — aucun test ne consomme de tokens et
aucun ne touche le réseau. `AnthropicClient` est testé via l'adaptateur de
test intégré à Faraday, les passes IA via une doublure de client
(`FakeAnthropicClient`), et l'interface admin en test d'intégration avec un
`Redaction::Brouillon` branché sur cette doublure.

---

## Ce qui n'existe pas encore

- **Pas de texte d'article en automatique.** Le récit automatique part du résumé et du
  chapeau : il reste court et factuel. La presse n'y passe jamais (voir `Veille::Connectors::Presse`) :
  pour un article de presse, l'admin le retient dans `/admin/veille/presse`, puis colle son texte.
- **Pas de traitement par lots depuis l'écran.** Chaque rédaction manuelle est synchrone et unitaire.
- Le récit de la fiche créée n'est qu'une amorce, à développer dans `/admin/stories`.
- Les trois idées de sources à reprendre (JSON-LD `Event`, CCI et Lorr'Up, dates françaises) sont
  décrites dans `docs/veille-auto.md`.

---

## Sources et tri, version 2 (branche `veille-sources-v2`, 11/11/2026)

### Presse locale : flux RSS, conditions de réutilisation d'abord

`config/veille/flux_presse.yml` (`Veille::AnnuairePresse`) dit, source par source, si le flux existe et si les
conditions d'utilisation du journal permettent de le lire. `Connectors::FluxPresse` ne lit que les sources
`reutilisation: non_opposee`. Il stocke le titre, le lien d'origine, la date, la source et l'extrait fourni par le flux
(400 caractères au plus) ; il n'ouvre jamais l'article. Le type (belle histoire ou opportunité) est tranché par l'IA selon
la règle éditoriale (un récit sans horaires ni appel à agir = belle histoire ; ce qui appelle à agir = opportunité).
La fiche publiée est réécrite, avec un lien « Pour en savoir plus » vers la source (`Veille::Validation`).

| Source | Flux | Décision |
|---|---|---|
| ICI Lorraine | `ici.fr/rss/{lorraine-nord,sud-lorraine}/a-la-une.xml` | **non lue** (11/11, étape 5) : CGU ICI art. VII et IX-1, usage par l'IA interdit sans accord écrit de Radio France et France Télévisions |
| France 3 Lorraine (Nancy) | `france3-regions.franceinfo.fr/grand-est/meurthe-et-moselle/nancy/rss` | **non lue** (11/11, étape 5) : CGU France Télévisions art. 13 « Text And Data Mining Policy » : opposition expresse, IA comprise |
| L'Est Républicain, Le Républicain Lorrain, Vosges Matin | flux existants | **non lus** : CGU « s'oppose à la fouille de textes et de données », usage IA compris (reste : lecture humaine `/admin/veille/presse`) |
| Actu Nancy | aucun flux Nancy (404) | **non lu** : CGU identiques en esprit |

### Tri par IA (`Veille::AiEnricher`)

- Modèle : `VEILLE_MODEL` (défaut `claude-haiku-5-5`). Effort `low` (`VEILLE_EFFORT` pour changer ; non envoyé aux modèles antérieurs à la génération 5).
- Escalade : si la confiance est entre **40 et 70 sur 100** (0,4 à 0,7), second passage avec `VEILLE_MODEL_ESCALADE` (défaut `claude-sonnet-5-5` ; Opus par configuration : `claude-opus-5-5`) ; son avis remplace le premier, et un élément écarté au premier passage peut revenir dans la file. Désactivée si les deux modèles sont identiques.
- Sortie : type, famille (d'où la catégorie), commune et zone (appartenance au Grand Nancy), dates, confiance 0-100, résumé réécrit en deux phrases, motif. Le score est stocké sur 100 (0,55 = 55).
- Le **doublon** n'est pas jugé par l'IA : `Candidate.doublon?` le fait avant tout appel (même URL ; ou même titre normalisé à la même date, ou à la même origine sans date).
- Jetons : chaque appel est une ligne de `veille_appels_ia` (modèle, passe `enrichissement`/`escalade`/`redaction`, entrée, sortie, coût). Le journal de chaque exécution (`[Veille] bilan`) donne les jetons par modèle ; `/admin/veille` affiche la dépense du mois contre le plafond (`VEILLE_BUDGET_MENSUEL`).

### Validation humaine

Rien ne se publie seul : tout arrive « à valider » (`pending`) dans `/admin/veille` avec source, score IA, résumé et lien d'origine.
Boutons : **Valider** (publie, `Veille::Validation`), **Écarter**, **À vérifier**, **Aperçu**, et l'écran de la fiche pour modifier avant de publier.

### Sources d'opportunités examinées

| Source | Décision | Raison |
|---|---|---|
| Agenda de la Ville de Nancy / Métropole | déjà en place (`AgendaNancy`) | l'API mutualisée n'expose que l'entité `vdn` ; les autres entités répondent 500 |
| HelloAsso | **écartée** | pas d'API de découverte publique (OAuth réservé aux organisations, 401) ; pages de recherche en 403 et interdites par robots.txt |
| France Bénévolat | **écartée** | ni flux ni API ; HTML seul, `Crawl-delay: 10` ; JeVeuxAider (API Engagement) couvre déjà le bénévolat |
| EFS (collectes de sang) | **écartée** | seule l'API cartographique interne du site existe, sans conditions de réutilisation publiées ; non sondée |

Variables : `VEILLE_MODEL`, `VEILLE_MODEL_ESCALADE`, `VEILLE_EFFORT`, `VEILLE_BUDGET_MENSUEL` (l'ancien nom `VEILLE_BUDGET_USD_MOIS` reste lu), `VEILLE_PRESSE_ACTIVE`.

### Sécurisation, coût, mesure (étapes 0 à 7 du 11/11/2026)

- **Préfiltre en code** (`Veille::Prefiltre`, `config/veille/prefiltre.yml`) : appliqué aux flux de presse avant stockage et avant tout appel IA. Retenu = territoire (20 communes du Grand Nancy, Meurthe-et-Moselle, Lorraine…) ET thème Déclic (engagement, bénévolat, associations, entrepreneuriat, solidarité, écologie, portraits, initiatives) ET aucune exclusion (sport, faits divers, météo, politique nationale, horoscope). Mots entiers, sans accents ni casse ; les listes se modifient sans toucher au code. Le journal du run donne : `[Veille] préfiltre presse — reçus N, retenus N, écartés N (motifs)`. Les autres sources (agenda, communes) ne sont pas préfiltrées.
- **Plafond** : `VEILLE_BUDGET_MENSUEL` (15 $), calculé sur `veille_appels_ia`. Atteint : aucun appel ne part, les éléments restent `pending` sans enrichissement (« non triés ») et `/admin/veille` affiche un bandeau.
- **Interrupteur** `VEILLE_PRESSE_ACTIVE` (défaut faux) : tant qu'il n'est pas `true`/`1`/`oui`, `FluxPresse` sort du job quotidien (`Runner.quotidien`) et les éléments de presse déjà stockés ne sont pas envoyés à l'IA. **Ne pas l'allumer** : les deux flux sont aujourd'hui `restreinte` (voir ci-dessus) et le connecteur n'a plus aucune source.
- **Banc d'essai** : `rake veille:banc_essai` (clé dans `.env`) trie les mêmes candidats avec Haiku 5.5 puis Sonnet 5.5, écrit un CSV (types, scores, jetons, coût, colonne « avis de Nicolas ») et donne accord et coût pour 100 éléments. Refuse les origines de presse restreintes sauf `AUTORISATION_ECRITE=1`.
