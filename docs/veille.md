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
fichier d'URL          rake veille:import
      |                        |
      |  une URL par ligne     |  PageFetcher : Open Graph -> JSON-LD -> <title>
      v                        v
                        Veille::Candidate (status: pending)
                               |
                               |  PASSE A - Veille::Qualifier (Haiku)
                               |  sur title + excerpt SEULEMENT
                               v
                        category . score . reason . qualified_at
                               |
                  /admin/veille - file par score decroissant
                               |
                     Retenir --+-- Ecarter
                        |             `--> status: ecarte
                        v
                  status: retenu
                        |
                        |  l'admin colle le texte de l'article
                        v
                    full_text
                        |
                        |  PASSE B - Veille::Drafter (Sonnet)
                        |  tronque a 12 000 caracteres
                        v
        { titre, personne, commune, resume, theme, champs_manquants }
                        |
                        |  formulaire editable, relu a la main
                        v
                   Publier --> Story (is_active: false)
                                  |
                                  `--> full_text = nil   <-- la regle
                                       status: publie
```

Aucun collecteur automatique n'existe à ce stade. **L'entrée se fait
uniquement par une liste d'URL fournie à la main**, pour permettre de régler
les prompts sur du réel avant de brancher la moindre collecte.

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
| `title`, `excerpt`, `published_on` | extraits par `PageFetcher` |
| `url` | obligatoire, **unique et indexée** — c'est la clé de dédoublonnage |
| `full_text` | le tampon. Voir la règle ci-dessus |
| `category` | `belle_histoire` ou `autre` ; `nil` avant qualification |
| `score` | 0 à 100 ; `nil` avant qualification. **Indexé** |
| `reason` | une phrase, écrite par la passe A |
| `status` | `pending` -> `retenu` / `ecarte` -> `publie`. **Indexé** |
| `qualified_at` | horodatage de la passe A |

Scope principal : `file_de_tri` — les `pending`, meilleur score d'abord, les
non qualifiés en dernier.

### `Story`

Le modèle de la rubrique **existait déjà** (`/stories`, `/admin/stories`) et
portait déjà `source_url` et `source_name`. Seul `veille_candidate_id` a été
ajouté. Supprimer un candidat ne détruit pas la fiche publiée : `nullify`.

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

### `Veille::Qualifier` — passe A

`claude-haiku-4-5-20251001`, sur **`title` + `excerpt` uniquement**. Le texte
intégral n'est jamais envoyé au tri. Rend et persiste :

```json
{ "category": "belle_histoire" | "autre", "score": 0-100, "reason": "une phrase" }
```

Les critères du prompt système : une belle histoire met en scène **une
personne nommée ou un petit collectif identifié**, raconte **une trajectoire
ou une initiative concrète**, et **s'ancre dans le Grand Nancy ou en
Meurthe-et-Moselle**. Le score reflète la force de ces trois éléments réunis.

Reçoivent `autre` sans hésiter, quel que soit leur intérêt : faits divers,
résultats sportifs, comptes rendus de conseil municipal, annonces
institutionnelles.

En cas d'échec, le candidat reste en base sans qualification — il est
repassable.

### `Veille::Drafter` — passe B

`claude-sonnet-5`, sur `full_text`. Rend :

```json
{ "titre": "…", "personne": "…", "commune": "…",
  "resume": "trois phrases", "theme": "…", "champs_manquants": ["…"] }
```

Contrainte centrale du prompt système : **le résumé est une reformulation
intégrale, dans un vocabulaire et une syntaxe propres. Aucune phrase ni
tournure de l'article d'origine n'y figure.** Seuls les faits sont repris —
noms, lieux, dates, chiffres.

Le modèle **renseigne `champs_manquants` plutôt que de combler par
déduction**. Une fiche honnêtement lacunaire vaut mieux qu'une fiche complète
et fausse. Les champs signalés apparaissent en jaune dans le formulaire.

`#draft` **ne persiste rien** : le brouillon repart vers un formulaire relu à
la main.

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

Aucun worker dyno sur ce projet : **la rédaction se fait dans la requête
web, en synchrone**. Le timeout Heroku est de 30 secondes.

| | `open_timeout` | `timeout` | `retries` | pire cas |
|---|---|---|---|---|
| `Veille::Qualifier` | 5 s | 20 s | 1 | tâche rake, hors contrainte |
| `Veille::Drafter` | 5 s | 22 s | **0** | **27 s** |

`retries: 0` sur la passe B n'est pas un détail : un seul retour en arrière
doublerait le temps de réponse et ferait sauter les 30 secondes. Le plafond
de **12 000 caractères** sur `full_text` sert le même objectif, et borne le
coût par appel. La troncature est journalisée :

```
[Veille::Drafter] full_text tronqué pour le candidat #42 : 30000 -> 12000 caractères
```

Si vous touchez à `TIMEOUT`, `OPEN_TIMEOUT` ou `RETRIES`, gardez leur somme
sous 30 s. Un test le vérifie (`test/services/veille/drafter_test.rb`).

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

Pour chaque URL : récupération de la page, extraction des métadonnées,
création du candidat, puis qualification. **Une seconde entre deux
requêtes**, et un User-Agent qui identifie Déclic :

```
DeclicVeille/1.0 (+https://declic.site)
```

Les URL déjà en base sont ignorées. Bilan en fin de tâche : candidats créés,
qualifiés en `belle_histoire`, qualifiés en `autre`, déjà connus, et le
détail des échecs le cas échéant.

### Trancher, rédiger, publier

`/admin/veille` — la file des candidats en attente, meilleur score d'abord.
Chaque ligne affiche titre, chapeau, source, date, score et motif, avec le
lien vers l'article qui s'ouvre dans un onglet.

- **Retenir** / **Écarter** : la ligne disparaît de la file sans
  rechargement (Turbo Stream).
- Onglet **Retenus** -> **Rédiger** ouvre l'écran à deux colonnes.
- À gauche l'article et ses métadonnées, à droite la zone où coller le texte.
- **Rédiger** appelle Sonnet ; le brouillon revient sans rechargement dans un
  formulaire éditable. Relisez-le, en particulier les champs signalés comme
  manquants.
- **Publier** crée la fiche en brouillon (`is_active: false`) et vide
  `full_text`. La fiche se termine ensuite dans `/admin/stories`.

### Sources

`/admin/veille/sources` — CRUD minimal. Supprimer une source conserve ses
candidats et les détache simplement.

---

## Configuration

| Variable | Rôle |
|---|---|
| `ANTHROPIC_API_KEY` | obligatoire pour les deux passes |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | authentification admin (HTTP Basic) |

`ANTHROPIC_MODEL` n'est **pas** utilisé par la veille : chaque passe choisit
son modèle explicitement.

---

## Tests

```bash
bin/rails test test/models/veille test/models/story_test.rb \
               test/services test/controllers/admin/veille
```

Tous les appels API sont bouchonnés — aucun test ne consomme de tokens et
aucun ne touche le réseau. `AnthropicClient` est testé via l'adaptateur de
test intégré à Faraday, les deux passes via une doublure de client, et
l'interface admin en test d'intégration avec `Veille::Drafter` bouchonné.

---

## Ce qui n'existe pas encore

- **Aucun collecteur.** `Veille::Source#last_collected_at` et le booléen
  `active` sont là pour le jour où il y en aura un.
- **Aucun traitement par lots.** Chaque appel est synchrone et unitaire.
- Le `body` de la fiche publiée n'est qu'une amorce : le résumé de trois
  phrases plus le lien vers la source. Le récit se développe ensuite dans
  `/admin/stories`.
