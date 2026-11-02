# Veille sur les réseaux sociaux des communes du Grand Nancy : diagnostic

Date : 02/11/2026. Diagnostic seul, aucun code touché.

**Limites de l'enquête.** Je n'ai pas pu ouvrir les pages Facebook ni Instagram des communes, qui sont fermées aux visiteurs non connectés. Je n'ai donc pas mesuré leur activité. Les constats sur les sites communaux (RSS, liens vers les pages sociales) viennent de requêtes faites le 02/11. Les conditions Meta viennent de sa documentation et de commentaires de juristes et d'éditeurs : à relire sur developers.facebook.com avant toute décision.

## 1. Architecture actuelle de la veille (point de comparaison)

Chaîne (`docs/veille-auto.md`) : `rake veille:quotidien` → `Veille::Runner` → connecteurs (`app/services/veille/connectors/`) → `RawIngester` (dédoublonnage, hors périmètre et passé écartés) → `AiEnricher` (Haiku : type, catégorie, commune, dates, résumé) → `Redaction::Brouillon` (Sonnet, belles histoires) → `Controles` → relecture dans `/admin/veille` → `Validation` (seul chemin vers une fiche inactive). Tout passe par `Veille::Http`, qui lit le `robots.txt`, respecte le Crawl-delay et attend 1 s minimum entre deux appels. Le plafond de dépense IA est de 15 $ par mois.

- **Agenda Grand Nancy** (`connectors/agenda_nancy.rb`) : une API JSON publique (`agenda-integration.grandnancy.eu/api/vdn/events`), celle qui alimente nancy.fr/agenda. Son `robots.txt` ne s'oppose à rien. Il n'y a pas de scraping HTML. Quatre rubriques sont gardées et fiabilité « haute ». Entièrement automatique.
- **Presse** (`connectors/presse.rb`) : volontairement hors du Runner. Les CGU de L'Est Républicain s'opposent à la fouille de textes, donc `/admin/veille/presse` lit le flux RSS à l'affichage et ne montre que titre et lien. Rien n'est stocké, rien ne va à l'IA, le chapeau n'est jamais lu. Un article n'entre en base que par le geste « Retenir » de l'admin, et le candidat créé est ignoré par les passes automatiques (`Candidate.hors_presse`). La Gazette France a été retirée du quotidien pour la même raison.
- **Principe commun** : une source n'est automatisée que si elle publie ses données de façon ouverte (API ou RSS, `robots.txt` permissif). Sinon, geste humain.

## 2. Faisabilité technique et légale

### 2.1 API officielle Meta

**Facebook (Graph API).** Lire les publications d'une page qu'on ne gère pas exige la fonctionnalité *Page Public Content Access* (PPCA). D'après la page officielle de Meta :
- passage obligatoire par l'App Review de Meta ;
- vérification de l'entreprise (*business verification*), avec parfois des contrats supplémentaires ;
- avant validation, l'appli ne lit que les pages dont l'admin a un rôle sur l'appli, donc pas celles des communes ;
- usage autorisé : « analyser et/ou afficher » les publications et interactions des pages. Les commentaires d'éditeurs indiquent que Meta refuse les demandes dont l'usage ne cadre pas avec cela.

C'est gratuit, mais il faut une entité vérifiable (association ou société avec justificatifs), une demande argumentée, et accepter que Meta la refuse ou la retire. Pour un projet de cette taille, c'est lourd et incertain. Les quotas précis ne sont pas confirmés par les sources que j'ai pu lire.

**Instagram.** Le seul accès officiel à d'autres comptes passe par *Business Discovery*, qui exige un compte professionnel de notre côté, une appli validée par Meta, et un compte cible lui aussi professionnel. Les sources que j'ai trouvées divergent sur la possibilité de lire les légendes des publications, et je n'ai pas pu ouvrir la documentation officielle (404). Cela reste à confirmer. Le quota cité par des tiers est d'environ 200 appels par heure.

### 2.2 Conditions d'utilisation et scraping

Les conditions de Meta (section 3.2.3) interdisent de collecter des données sur ses produits par des moyens automatisés sans autorisation préalable, y compris connecté. Le risque est donc **du même ordre que celui des CGU de L'Est Républicain**, et plus fort : Meta bloque activement les robots.

Un jugement californien de janvier 2024 (*Meta c. Bright Data*) a écarté la rupture de contrat pour du scraping non connecté de données publiques. Il ne protège pas un projet qui se connecterait. Il ne vaut pas règle en France, et d'autres fondements existent (bases de données, RGPD). Je n'ai pas vérifié si Meta a fait appel.

Autre problème, propre à ce projet : la règle maison est que `Veille::Http` lit le `robots.txt` avant toute requête. Facebook et Instagram n'offrent aucun accès conforme à cette règle.

**Conclusion : le scraping des réseaux sociaux n'est pas une option.** Les services tiers de scraping (Apify et semblables) ne font que déplacer le risque et ajoutent un coût.

### 2.3 Alternatives plus simples : **les sites des communes**

Constat de terrain, qui change la donne : les communes publient presque tout sur leur propre site, et plusieurs exposent un flux RSS WordPress ouvert.

| Commune | Site | Flux RSS (02/11) |
|---|---|---|
| Ludres | ludres.com | `/feed/` : actif, articles du jour |
| Vandœuvre-lès-Nancy | vandoeuvre.fr | `/feed/` : actif, articles du jour (forum emploi, conférence…) |
| Maxéville | maxeville.fr | `/index.php/feed/` : actif, articles du 30 et 31/10 |
| Malzéville | villedemalzeville.fr | `/feed/` : répond, aucun article lu |

Ces flux sont des données publiées par des collectivités pour être reprises, comme l'API de l'Agenda Grand Nancy. Il reste à relire les mentions légales de chaque site avant de les brancher. Pour les autres communes, rien de vérifié : voir le tableau suivant.

## 3. Les 19 communes hors Nancy

La liste est celle de `Veille::GrandNancy::COMMUNES`. « Pages sociales » = liens trouvés sur la page d'accueil du site communal. **Je n'ai pas pu mesurer l'activité ni la pertinence des publications.**

| Commune | Site joignable | Pages sociales trouvées | RSS |
|---|---|---|---|
| Art-sur-Meurthe | non (domaine testé injoignable) | – | – |
| Dommartemont | résolu mais page non lue | – | – |
| Essey-lès-Nancy | 403 (bloque les robots) | – | – |
| Fléville-devant-Nancy | non (domaine testé injoignable) | – | – |
| Heillecourt | oui | Facebook (plusieurs pages) | non vu |
| Houdemont | oui | Facebook + Instagram | non vu |
| Jarville-la-Malgrange | oui | non trouvées | non vu |
| Laneuveville-devant-Nancy | non (domaine testé injoignable) | – | – |
| Laxou | oui | Facebook + Instagram | non vu |
| Ludres | oui | Instagram | **oui** |
| Malzéville | oui | Facebook + Instagram | **oui** (vide) |
| Maxéville | oui | Facebook + Instagram | **oui** |
| Pulnoy | oui | Facebook | non vu |
| Saint-Max | oui | Facebook | non vu |
| Saulxures-lès-Nancy | non (domaine testé injoignable) | – | – |
| Seichamps | résolu mais page non lue | – | – |
| Tomblaine | 503 | – | – |
| Vandœuvre-lès-Nancy | oui | Facebook + Instagram | **oui** |
| Villers-lès-Nancy | oui (villerslesnancy.fr) | Instagram | non vu |

Les « non » sont souvent un mauvais domaine de ma part, pas une absence de site. Il faut établir l'annuaire à la main avant tout développement.

## 4. Recommandation

**Option (b), version allégée : un workflow semi-manuel, et non une intégration Meta.**

- **(a) API Meta : écartée.** Vérification d'entreprise, App Review, usage « analyse/affichage » qui ne correspond pas à notre besoin, et dépendance à une décision de Meta. L'effort administratif dépasse la valeur d'une dizaine de communes.
- **(c) Ne rien faire : inutile**, car il existe une voie plus propre.
- **(b) Recommandée en deux temps :**
  1. **Flux RSS des sites communaux**, sur le modèle de l'Agenda Grand Nancy (automatique, `robots.txt` respecté) : un connecteur `Veille::Connectors::Communes` avec une liste d'URL de flux. Les articles tombent en brouillon dans `/admin/veille`, passent par l'IA et la relecture comme les autres. Quatre communes sont à brancher dès maintenant (Ludres, Vandœuvre, Maxéville, Malzéville). Il faudra juger si ces articles sont des annonces d'événements ou des actualités générales (l'enrichissement tranche déjà opportunité ou histoire).
  2. **Pour les communes sans flux** : une page `/admin/veille/communes` sur le modèle de `/admin/veille/presse`, qui liste les liens vers leurs agendas et pages sociales. La rédaction repère une annonce, puis la saisit ou la colle via « Retenir ». Aucun appel automatique à Facebook ni Instagram.

**Ordre de grandeur de l'effort**
- Étape 1 : environ 1 journée (connecteur sur le patron d'`agenda_nancy.rb`, tests, lecture des mentions légales). Coût IA marginal sous le plafond de 15 $.
- Étape 2 : environ une demi-journée, en copiant le contrôleur et la vue de la presse.
- Préalable non technique : une demi-journée pour établir l'annuaire des 19 communes (site, flux, pages sociales) et lire leurs mentions légales.

**À décider avant de coder** : accepter que les réseaux sociaux ne soient lus que par des humains, et les communes sans RSS suivies à la main.

## Sources
- [Meta : Page Public Content Access](https://developers.facebook.com/docs/features-reference/page-public-content-access)
- [Conditions d'utilisation Facebook, § 3.2](https://www.facebook.com/terms)
- [Meta c. Bright Data : analyse (FBM)](https://www.fbm.com/business-litigation/publications/major-decision-affects-law-of-scraping-and-online-data-collection-meta-platforms-v-bright-data/)
- [Instagram API en 2026 (Phyllo)](https://www.getphyllo.com/post/instagram-api-guide) : source tierce, à recouper avec la doc Meta
- Code et docs du dépôt : `docs/veille-auto.md`, `docs/veille.md`, `app/services/veille/connectors/{agenda_nancy,presse}.rb`, `app/services/veille/grand_nancy.rb`
