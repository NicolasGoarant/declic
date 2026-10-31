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
connecteurs (rake veille:quotidien / hebdomadaire)      rake veille:import (liste d'URL)
        |                                                      |
        v                                                      v
   RawIngester : dédoublonne, écarte hors Grand Nancy / passé    PageFetcher
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
la règle éditoriale), catégorie, commune du Grand Nancy, date ou régime, résumé reformulé en
deux phrases (au plus 15 mots consécutifs repris de la source). Écarte ce qui est hors Grand
Nancy ou passé. Les sources officielles (JeVeuxAider, agenda, formation, Transentreprise) sont
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

Budget mensuel d'après `veille_appels_ia`, réglable par `VEILLE_BUDGET_USD_MOIS` (15 $ par
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
| `VEILLE_BUDGET_USD_MOIS` | plafond mensuel de l'API, en dollars (15 par défaut) |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | authentification admin (HTTP Basic) |

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
  chapeau (la presse n'est lue que par flux RSS) : il reste court et factuel. Pour un récit plus
  riche, l'admin colle le texte de l'article.
- **Pas de traitement par lots depuis l'écran.** Chaque rédaction manuelle est synchrone et unitaire.
- Le récit de la fiche créée n'est qu'une amorce, à développer dans `/admin/stories`.
- Les trois idées de sources à reprendre (JSON-LD `Event`, CCI et Lorr'Up, dates françaises) sont
  décrites dans `docs/veille-auto.md`.
