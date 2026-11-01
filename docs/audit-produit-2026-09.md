# Audit produit Déclic — septembre 2026

**Périmètre** : branche `main`, commit `c1a40d7`. Analyse en lecture seule dans un
worktree détaché. Aucune ligne de code modifiée.

Complémentaire à [`audit-2026-09.md`](audit-2026-09.md), qui portait sur la sécurité
et la solidité technique. Celui-ci ne traite ni des failles ni des performances : il
regarde ce que le site raconte, ce qu'un visiteur constate, et où en est le chantier.

Les deux rapports se croisent en deux endroits seulement, signalés au passage.

Classement demandé : par gêne réelle. Trois niveaux — ce qu'un visiteur subit, ce qui
vous ralentit, le cosmétique. Les questions transversales (vocabulaire, modèle de
données, état du chantier) sont reprises en synthèse à la fin, avec renvois.

---

## A. Ce qu'un visiteur subit

---

### A1 — La page presse annonce trois articles qui n'existent pas, attribués à des médias réels

**Où** : `app/views/pages/presse.html.erb:100-160`

Sous le titre « **Ils parlent de nous** — Déclic dans la presse locale et nationale »,
trois blocs complets :

| Média cité | Titre affiché | Date affichée |
|---|---|---|
| L'Est Républicain | « Déclic : la plateforme qui cartographie l'engagement citoyen à Nancy » | Décembre 2024 |
| France Bleu Lorraine | « Comment s'engager localement grâce au numérique ? » | Novembre 2024 |
| France 3 Grand Est | « Déclic, l'appli qui donne envie de passer à l'action » | Octobre 2024 |

Chacun avec un chapô rédigé (« Interview des fondateurs de Déclic… », « Reportage sur
la plateforme Déclic… ») et un lien « Lire l'article → » qui pointe sur `href="#"`.

Le commentaire à la ligne 111 dit ce qu'il en est : `<%# Exemple d'article - À adapter
avec vos vraies apparitions %>`. Ce sont des exemples de gabarit jamais remplacés.

Et juste en dessous, ligne 158-160, le démenti :

```erb
<%# Message si aucune apparition réelle pour l'instant %>
<p><em>🚀 Déclic est un projet récent. Les premières apparitions médias
   arriveront bientôt ! Vous êtes journaliste ? Contactez-nous.</em></p>
```

**Ce que ça produit.** La page affirme trois passages presse et, deux centimètres plus
bas, qu'il n'y en a aucun. Un lecteur attentif comprend que le reste de la page est
peut-être du même tonneau.

Le problème dépasse la maladresse : ces articles sont attribués nommément à trois
rédactions identifiables, avec titre, date et extrait. La page `/presse` est
précisément celle qu'un journaliste consulte. Si quelqu'un de L'Est Républicain
tombe dessus, il y lit un article qu'il n'a pas écrit sous l'enseigne de son journal.
C'est le genre de chose qui se règle mal après coup, et c'est aussi la page la plus
susceptible d'être partagée à un partenaire ou à un financeur.

C'est le premier point du rapport parce que c'est le seul dont le coût n'est pas
seulement une gêne d'usage.

**Effort** : 15 min pour supprimer les trois blocs et garder le message honnête, qui
est bien tourné et suffit.

---

### A2 — Les messages d'erreur des formulaires publics s'affichent en anglais

**Où** : `config/locales/` ne contient que `en.yml`, resté à l'état de gabarit Rails
(commentaires seuls). `default_locale` n'est défini nulle part. Rendu par
`app/views/opportunities/new.html.erb:30` et `app/views/stories/new.html.erb:27` :

```erb
<% @opportunity.errors.full_messages.each do |msg| %>
```

**Ce que ça produit.** Un visiteur qui oublie un champ obligatoire sur « Proposer une
opportunité » voit, sous un bandeau français, la liste suivante :

```
Title can't be blank
Description can't be blank
Category is not included in the list
Contact email is invalid
```

Ce n'est pas un détail de finition : c'est le seul moment où le site s'adresse
directement au visiteur pour lui dire qu'il s'est trompé, et c'est le moment où il
bascule en anglais. Sur les deux formulaires de contribution — c'est-à-dire sur les
deux seuls parcours où quelqu'un donne quelque chose au site.

Les mêmes messages remontent dans l'admin via
`app/controllers/admin/stories_controller.rb:47`
(`@story.errors.full_messages.to_sentence`), donc vous les voyez aussi.

Accessoirement, `Category is not included in the list` ne dit pas au visiteur quelles
catégories sont admises.

**Effort** : 30 min. Un `config/locales/fr.yml` avec la traduction Rails standard, les
`activerecord.attributes` des deux modèles, et `config.i18n.default_locale = :fr`.

---

### A3 — Deux des quatre liens du menu principal ne mènent nulle part

**Où** : `app/views/shared/_navbar.html.erb:34-39` (desktop) et `:112-119` (mobile)

```erb
<%= link_to "Parcours",     root_path(anchor: "parcours")    %>
<%= link_to "Témoignages",  root_path(anchor: "temoignages") %>
```

Les ancres cibles n'existent pas. Les seuls `id` d'ancrage présents dans les vues
publiques sont `explorer` (`home.html.erb:128`), `stories` (`:208`) et `contribuer`
(`:239`). Ni `parcours` ni `temoignages` n'apparaissent nulle part — vérifié sur
l'ensemble de `app/views`, fichiers `.bak` exclus.

Le comble : la section témoignages existe bel et bien (`home.html.erb:277`), elle n'a
simplement pas d'`id`. Et la section « Belles Histoires » en a un — `stories` — que
personne n'utilise.

**Ce que ça produit.** Sur les quatre entrées du menu, deux ne font rien de visible.
Depuis la page d'accueil, le clic ne bouge pas la page. Depuis une autre page, il
ramène en haut de l'accueil, ce que le visiteur interprète comme un bug de navigation.
Sur mobile, le menu se referme en prime, donnant l'impression que l'action a été prise
en compte.

**Effort** : 5 min. Poser `id="temoignages"` sur la section ligne 278, et arbitrer
« Parcours » — qui renvoie à une fonctionnalité inachevée, voir A4.

---

### A4 — Le filtre par catégorie de `/parcours/:category` n'est pas appliqué

**Où** : route `config/routes.rb:17`, contrôleur
`app/controllers/opportunities_controller.rb:5-7`

```ruby
get "/parcours/:category", to: "opportunities#index", as: :parcours
```

```ruby
def index
  @opportunities = Opportunity.active.order(created_at: :desc).limit(100)
end
```

`params[:category]` n'est jamais lu par le contrôleur.

Mais la vue, elle, le lit — `app/views/opportunities/index.html.erb:59` :

```erb
<% current_cat = params[:category].to_s.downcase.presence || 'toutes' %>
```

**Ce que ça produit.** Sur `/parcours/benevolat`, la pastille « Bénévolat » s'affiche
comme active en haut de page, et la liste en dessous contient les cinq catégories. Le
site affirme filtrer et ne filtre pas — plus déroutant qu'une page qui n'aurait rien
promis.

À décharge : aucun lien du site ne pointe vers `parcours_path`. La route n'est
atteignable que par saisie directe ou par un lien externe. Elle reste indexable, et
c'est le genre d'URL propre qu'on met dans une communication.

À rapprocher de deux constats de l'autre rapport : `@journey_cards`
(`pages_controller.rb:7-20`) construit à chaque requête et jamais affiché, et l'entrée
de menu « Parcours » qui pointe sur une ancre morte (A3). Le « parcours » est un
concept déclaré à quatre endroits et implémenté nulle part. Voir la section
**État du chantier**.

**Effort** : 20 min pour appliquer le filtre. Ou 5 min pour retirer la route, si le
parcours n'est plus la direction retenue.

---

### A5 — Les deux pages légales se contredisent, et contredisent le site

**Où** : `app/views/pages/legal.html.erb` et `app/views/pages/confidentialite.html.erb`

Quatre problèmes distincts, du plus au moins grave.

**a) « Aucune donnée personnelle » — `legal.html.erb:63`**

> « Actuellement, Déclic ne collecte **aucune donnée personnelle** des visiteurs du
> site. »

C'est faux, et c'est vérifiable en trois clics sur le site lui-même. Les deux
formulaires publics collectent nom, e-mail, téléphone, adresse, code postal, ville et
photos (`stories_controller.rb:42`, `opportunities_controller.rb:50-63`). Le formulaire
« Raconter mon histoire » rend d'ailleurs l'adresse et le code postal **obligatoires**
(`stories/new.html.erb:66` et `:70`).

La page `/confidentialite` dit l'inverse au même moment — ligne 90, elle mentionne le
consentement « lorsque vous soumettez volontairement des informations (formulaires,
contact) ». Les deux pages sont en ligne simultanément.

Le lien avec l'autre rapport : le point 2.11 y signale que téléphone et adresse
partent en clair dans les logs Heroku, faute de figurer dans `filter_parameters`. Une
politique qui affirme ne rien collecter et un journal applicatif qui enregistre tout
est la combinaison la moins défendable.

**b) Le statut juridique annoncé n'est pas celui de la structure — `legal.html.erb:24-25`**

> Nom : Nicolas Goarant — Statut : **Entrepreneur individuel**

Le dépôt contient `PV_AG_Constitutive_DECLIC_signe.pdf`, `Statuts_DECLIC_signes.pdf`,
`Declic_Fiche_OSBL_signee.pdf`, `Recepisse_CR.pdf` et une liste de dirigeants : Déclic
est une association déclarée. Les mentions légales décrivent une autre entité que
celle qui existe, sans numéro RNA ni SIRET.

**c) La date de mise à jour est recalculée chaque jour**

`legal.html.erb:17` — `Date.today.strftime("%d %B %Y")`
`confidentialite.html.erb:15` et `:225` — `Date.today.strftime("%d/%m/%Y")`

Les trois affichent la date du jour. Les conditions annoncent donc en permanence avoir
été révisées aujourd'hui, quelle que soit la date de la dernière modification réelle
(février 2026 pour l'une, d'après l'historique). C'est précisément l'information que
ce champ est censé porter, et c'est la seule qu'il ne donne pas.

Effet de bord : `%B` en Ruby n'est pas traduit par Rails, il suit la locale C. La page
`/mentions-legales` affiche donc « **05 September 2026** » — un mois en anglais sur la
page la plus formelle du site (voir aussi A2).

**d) Divergences de fond entre les deux pages**

| Sujet | `/mentions-legales` | `/confidentialite` |
|---|---|---|
| Localisation des données | « Union Européenne » (l.39) | « hébergé en France » (l.116) |
| Conservation navigation | « 12 mois maximum » (l.81) | « 13 mois maximum » (l.129) |
| Contact | `nicolas@declic.site` (l.27, l.97) puis `contact@declic.site` (l.152) | `contact@declic.site` |

Trois adresses de contact pour deux pages. Et `confidentialite.html.erb:130` évoque la
« fermeture du compte » alors qu'il n'existe aucun système de comptes — la FAQ le dit
elle-même (`faq.html.erb:69` : « Un compte n'est pas nécessaire »).

Une note au passage : l'adresse « 415 Mission Street, San Francisco » (`legal:37`) est
celle de Heroku, l'hébergeur. Elle est à sa place, ce n'est pas un reliquat de gabarit.

**Ce que ça produit.** Deux pages qui se contredisent sur un sujet réglementé, dont
une qui nie une collecte que le site pratique visiblement. Le risque n'est pas qu'un
visiteur le remarque — c'est qu'un partenaire, une collectivité ou un financeur le
remarque, sur les deux pages qu'on lit justement pour vérifier le sérieux d'une
structure.

**Effort** : 1 h 30 pour reprendre les deux pages ensemble : aligner statut, adresses,
durées, décrire la collecte réelle, et figer les dates de mise à jour en dur.

---

### A6 — Deux syntaxes différentes pour insérer une photo dans un texte

**Où** :
- Belles Histoires → `___INLINE_PHOTO_1_PLACEHOLDER___`
  (`app/helpers/stories_helper.rb:32`, expliqué dans `admin/stories/_form.html.erb:264-266`)
- Opportunités → `<!-- IMAGE_1 -->`
  (`app/helpers/opportunities_helper.rb:157`, expliqué dans `admin/opportunities/_form.html.erb:290`)

Les deux fonctionnalités sont identiques : trois photos, trois légendes, des marqueurs
posés dans le corps du texte. Les deux fonctionnent. Elles n'acceptent simplement pas
le même marqueur, et chaque formulaire d'admin enseigne le sien sur une dizaine de
lignes d'aide.

**Ce que ça produit.** L'erreur est inévitable — c'est le même geste sur deux écrans
qui se ressemblent — et elle est visible en production :

- un `<!-- IMAGE_1 -->` dans une histoire : `inline_format`
  (`stories_helper.rb:63`) échappe le HTML, donc **la chaîne `<!-- IMAGE_1 -->`
  s'affiche telle quelle** au milieu du récit ;
- un `___INLINE_PHOTO_1_PLACEHOLDER___` dans une opportunité : aucun remplacement,
  **le placeholder s'affiche en toutes lettres**.

Dans les deux cas la photo est bien uploadée et stockée, et n'apparaît pas.

**Effort** : 45 min pour faire accepter les deux syntaxes aux deux moteurs — plus sûr
qu'un renommage, qui casserait les contenus déjà saisis.

---

### A7 — Deux pages annoncent des chiffres différents pour la même chose

**Où** :

| | `/philosophie` | `/presse` |
|---|---|---|
| Opportunités | **100+** (l.654) | **200+** (l.32) |
| Histoires / témoignages | **50+** (l.662) | **50+** (l.33) |

Tous en dur dans le HTML.

**Ce que ça produit.** Un visiteur qui ouvre les deux pages — le cas typique d'un
partenaire potentiel, ce sont les deux pages « institutionnelles » — voit le catalogue
doubler d'une page à l'autre. Aucun des deux nombres n'est calculé, donc aucun n'est
juste, et ils vieillissent dans les deux sens : trop bas si le site grossit, trop haut
si vous désactivez des fiches expirées avec `declic:deactivate_expired`.

`Opportunity.active.count` et `Story.active.count` sont disponibles gratuitement.

**Effort** : 20 min pour brancher les compteurs sur la base, avec un arrondi si vous
préférez « 100+ » à un nombre exact.

---

### A8 — Les photos des témoignages ne correspondent pas aux prénoms affichés

**Où** : `app/views/pages/home.html.erb:288-315`

Quatre témoignages en dur, chacun avec prénom, rôle, citation et photo :

| Prénom affiché | Fichier photo utilisé | Fichier au bon nom |
|---|---|---|
| Lucile | `avatars/lucile.png` | ✅ cohérent |
| **Matthieu** | `avatars/francois.png` | `matthieu.jpeg` existe pourtant |
| **Karim** | `avatars/luc.png` | `karim.jpeg` existe pourtant |
| Emma | `avatars/emma.jpeg` | ✅ cohérent |

Les fichiers `matthieu.jpeg` (1,8 Mo) et `karim.jpeg` (1,8 Mo) sont bien présents dans
`app/assets/images/avatars/`. Ils ne sont simplement pas ceux qui sont référencés.

**Ce que ça produit.** Deux visages sur quatre ne sont pas ceux annoncés, dans le bloc
qui sert justement de preuve sociale. Personne ne s'en aperçoit tant qu'il ne connaît
pas les personnes — mais il suffit d'un proche pour que ce soit gênant, d'autant que
ces photos sont, à en juger par leur poids et leur nom, des photos de vraies gens.

Question de fond qui dépasse le bug : ces quatre témoignages sont des contenus fictifs
(prénom, rôle et citation rédigés) illustrés par des photos réelles. C'est le même
mécanisme qu'en A1, en moins exposé. À trancher.

**Effort** : 5 min pour corriger les deux chemins. Le reste est une décision, pas une
correction.

---

### A9 — Le bouton « Passer à l'action » ne peut jamais apparaître

**Où** : `app/views/opportunities/show.html.erb:477-483`

```erb
<% if @opportunity.cta_button_url.present? %>
  <%= link_to @opportunity.cta_button_url, ... %>
    <span class="mr-2">🚀</span> <%= @opportunity.cta_button_text.presence || "Passer à l'action" %>
```

Les colonnes existent (migration `20260115124107_add_cta_to_opportunities`). Le bloc
d'affichage existe. Mais :

- aucun champ `cta_button_url` ni `cta_button_text` dans
  `app/views/admin/opportunities/_form.html.erb` (547 lignes) ;
- ni l'un ni l'autre dans la liste `permit` de
  `admin/opportunities_controller.rb:88-158`.

Rien ne peut donc écrire ces colonnes, et la condition ligne 477 est toujours fausse.

**Ce que ça produit.** L'appel à l'action principal d'une fiche — le bouton par lequel
un visiteur passe du site à l'organisation — n'existe pas. Le visiteur qui a lu la
fiche jusqu'au bout n'a rien à cliquer. Le lien source (`:451-452`) reste, mais c'est
une attribution de source, pas une invitation.

Même situation, moindre enjeu, pour `source_author` : affiché ligne 462-463
(« Rédaction : … »), absent du formulaire et du `permit`.

**Effort** : 20 min (deux champs dans le formulaire, deux entrées dans le `permit`).

---

### A10 — Les dates saisies dans l'admin n'apparaissent sur aucune fiche

**Où** : comparaison entre `app/views/admin/opportunities/_form.html.erb` et
`app/views/opportunities/show.html.erb`.

Champs présents dans le formulaire d'admin et référencés **nulle part** dans la fiche
publique :

| Champ | Statut |
|---|---|
| `start_date` | saisi, jamais affiché |
| `end_date` | saisi, jamais affiché |
| `time_commitment` | saisi, jamais affiché |
| `contact_phone` | saisi, jamais affiché (mais bien envoyé dans l'e-mail de proposition) |
| `tags` | saisi, jamais affiché |

**Ce que ça produit.** Pour le visiteur : une fiche d'atelier ou d'événement sans date
ni durée. C'est l'information la plus déterminante pour décider d'y aller, et c'est la
seule qui manque. Pour vous : cinq champs remplis à chaque saisie sans aucun effet.

Deux remarques utiles :
- l'aide au remplissage du formulaire propose `start_date: "12/03/2026"` — or la
  colonne est un `string` (autre rapport, 3.3), donc aucun tri ni filtre par date n'est
  possible sur ce qui est saisi ;
- les colonnes `starts_at` / `ends_at` (vrais `datetime`, indexées) sont, elles,
  exposées par l'API et utilisées par `gcal_url` — mais absentes du formulaire d'admin.
  Les dates que vous saisissez et celles que le système exploite ne sont pas les mêmes.

**Effort** : 30 min pour afficher les champs existants. 1 h de plus si vous voulez
basculer la saisie sur `starts_at` / `ends_at` et récupérer le tri et le lien Google
Agenda.

---

### A11 — Six liens du site ne mènent nulle part

**Où** :

| Fichier:ligne | Libellé |
|---|---|
| `pages/presse.html.erb:124` | « Lire l'article → » |
| `pages/presse.html.erb:139` | « Écouter l'interview → » |
| `pages/presse.html.erb:154` | « Voir le reportage → » |
| `shared/_footer.html.erb:22` | Facebook (`aria-label="Déclic sur Facebook"`) |
| `shared/_footer.html.erb:25` | Instagram |
| `shared/_footer.html.erb:28` | LinkedIn |

Tous en `href="#"`.

Les trois premiers disparaissent avec A1. Les trois autres sont plus gênants : ils
apparaissent **sur toutes les pages** du site, avec un `aria-label` qui promet un
compte existant. Un lecteur d'écran annonce « Déclic sur Facebook, lien » ; le clic
remonte en haut de page.

**Ce que ça produit.** Trois icônes sociales inertes en pied de page, partout. Si les
comptes n'existent pas, les icônes ne devraient pas être là ; s'ils existent, il
manque trois URL.

**Effort** : 10 min.

---

### A12 — Le mode hors ligne de la PWA ne fonctionne pas

**Où** : `public/sw.js:12-19` et `:136-138`

```js
const PRECACHE_ASSETS = [ '/', '/explorer', '/offline' ];
...
const offline = await caches.match('/offline');
if (offline) return offline;
```

Sur les trois URL précachées, **deux n'existent pas** :
- `/offline` : aucune route. La vue `app/views/pages/offline.html.erb` est orpheline
  (déjà relevée dans l'autre rapport, 3.4).
- `/explorer` : c'est une ancre sur la page d'accueil (`home.html.erb:128`), pas une
  route.

Le `.catch()` ligne 28 évite que l'installation échoue — le service worker s'installe
donc normalement, et rien ne signale le problème.

**Ce que ça produit.** Le repli hors ligne ligne 137 ne trouve jamais rien en cache.
Un visiteur qui perd sa connexion — le métro, une zone blanche, exactement la
situation pour laquelle une PWA existe — reçoit la page d'erreur par défaut du
navigateur. La bannière d'installation (`shared/_pwa_banner.html.erb`) l'aura pourtant
invité à installer l'application.

À signaler au passage, sur le même sujet : il existe **deux** service workers et
**deux** manifests. `public/sw.js` (6 Ko) et `public/manifest.json` sont ceux que le
site charge (`layouts/application.html.erb:80` et `:18`) ;
`app/views/pwa/service-worker.js` (876 o) et `app/views/pwa/manifest.json.erb` sont le
gabarit Rails, sans route, jamais servis.

**Effort** : 20 min. Déclarer une route `/offline` vers la vue qui existe déjà, et
retirer `/explorer` de la liste de précache.

---

### A13 — Une même catégorie change de couleur et de nom selon l'endroit de la page

**Où** : quatre définitions distinctes, toutes dans `app/views/pages/home.html.erb`.

| Catégorie | Pastille carte<br>(l.68-75) | Filtre chips<br>(l.780-786) | Marqueur carte<br>(l.1115-1120) | Popup carte<br>(l.1178-1183) |
|---|---|---|---|---|
| Bénévolat | `#e11d48` | `#f43f5e` | — | — |
| Écologiser | `#16a34a` | `#22c55e` | `#16a34a` | `#16a34a` — **« Écologie »** |
| Formation | `#2563eb` | `#6366f1` | `#3b82f6` | `#3b82f6` |
| Rencontres | `#a16207` | `#eab308` | `#facc15` | `#facc15` |
| Entreprendre | `#c2410c` | `#f97316` | `#f59e0b` | `#f59e0b` — **« Entreprise »** |
| Histoires | `#9333ea` | `#ec4899` | `#a855f7` | `#a855f7` — « Témoignage » |

**Ce que ça produit.** Sur une seule page, une opportunité « Entreprendre » apparaît en
rouge-orangé sur sa vignette, en orange dans le filtre, en ambre sur la carte — et son
popup l'appelle « **Entreprise** ». Écologiser devient « **Écologie** » au même
endroit. La couleur ne sert donc à rien comme repère : elle ne relie pas le filtre au
marqueur.

Les libellés divergents sont le point le plus gênant, parce qu'ils suggèrent des
catégories qui n'existent pas dans le modèle
(`Opportunity::CATEGORIES`, `opportunity.rb:28`).

**Effort** : 30 min pour ramener les quatre tables à une seule source, côté helper.

---

### A14 — Le corps des fiches ne se comporte pas pareil selon le type de contenu

**Où** : `app/helpers/stories_helper.rb:146-256` (`render_story_body`, 111 lignes) et
`app/helpers/opportunities_helper.rb:196-302` (`render_opportunity_body`, 107 lignes).

Deux moteurs de rendu Markdown maison quasi jumeaux — 43 lignes strictement
identiques — mais divergents sur trois points, tous visibles :

| | Histoire | Opportunité |
|---|---|---|
| Image Markdown `![alt](url)` | rendue en `<figure>` (`render_image_line`, l.161) | **non gérée** → s'affiche en texte brut |
| Bloc `**À retenir**` | liste à coches vertes (l.201-212) | **non géré** |
| `###` précédé d'une espace insécable | reconnu (`  -​ `, l.169) | **non reconnu** (`[ \t]` seulement) |
| Lien dans le texte | sans classe (`stories_helper.rb:69`) | bleu souligné (`opportunities_helper.rb:53`) |

**Ce que ça produit.** Le troisième point est le plus traître : coller un texte depuis
Word, Google Docs ou une page web amène très souvent des espaces insécables. Le même
`### Mon titre` devient un titre dans une histoire et reste `### Mon titre` en texte
brut dans une opportunité. Rien dans l'admin ne l'explique.

Et un lien dans le corps d'une histoire n'est pas visuellement distinguable du texte,
alors qu'il l'est dans une opportunité.

**Effort** : 1 h pour aligner les deux moteurs. Voir B3 : la vraie question est
qu'il y en ait deux.

---

## B. Ce qui vous ralentit

---

### B1 — Le visiteur saisit ses coordonnées, vous devez les retaper

**Où** :
- formulaire public : `app/views/stories/new.html.erb:54-70` — champs `phone`,
  `address` (obligatoire), `city`, `postal_code`, plus `name` et `email`
- formulaire admin : `app/views/admin/stories/_form.html.erb:308-310` — un unique
  `text_area :contact_info`, avec pour indication
  `« Ex: contact@caseus.fr • 06 12 34 56 78 • … »`
- affichage public : `app/views/stories/show.html.erb:257-264` — seul `contact_info`
  est rendu

**Ce que ça produit.** Deux systèmes de contact coexistent sur le même modèle. Le
visiteur remplit six champs structurés ; aucun n'est affiché ni éditable dans l'admin.
Pour qu'un contact apparaisse sur la fiche publiée, vous devez ouvrir la fiche, aller
lire les valeurs ailleurs, et les **retaper** à la main dans un champ libre.

Sur les opportunités, c'est l'inverse et c'est cohérent : `contact_email`,
`contact_phone` et `website` sont structurés, éditables, et l'e-mail est affiché.

Conséquence en cascade : `contact_info` étant du texte libre, chaque fiche a sa mise
en forme (séparateurs, ordre, présence ou non de l'indicatif), là où le champ
structuré permettrait un `mailto:` et un `tel:` corrects.

**Effort** : 45 min pour afficher les champs structurés en lecture seule dans le
formulaire d'admin — ce qui supprime la ressaisie sans toucher au modèle.

---

### B2 — La colonne « Date » des listes d'admin n'est pas la date de l'événement

**Où** : `app/views/admin/opportunities/index.html.erb:31` et `:52`,
`app/views/admin/stories/index.html.erb:25` et `:48`

```erb
<th>Date</th>
...
<td class="date-cell"><%= o.created_at.strftime("%d/%m/%Y") %></td>
```

Les deux tableaux affichent `created_at` — la date de saisie — sous un en-tête
« Date ». Ni `start_date` / `starts_at` pour les opportunités, ni `happened_on` pour
les histoires.

**Ce que ça produit.** Vous ne pouvez pas repérer d'un coup d'œil ce qui est passé, ce
qui approche, ce qu'il faut désactiver. C'est justement le travail que
`declic:deactivate_expired` fait en ligne de commande — l'information manque à
l'endroit où vous décidez.

Le tri renforce l'effet : `created_at DESC` pour les opportunités, `COALESCE(updated_at,
created_at) DESC` pour les histoires. Deux tris différents pour deux écrans jumeaux.

**Effort** : 20 min (une colonne de plus, ou remplacer celle qui est là).

---

### B3 — Le même code existe en deux ou trois exemplaires

Recensement, du plus lourd au plus léger :

| Duplication | Emplacements | Taille |
|---|---|---|
| Moteur de rendu du corps | `stories_helper.rb:146` / `opportunities_helper.rb:196` | 111 + 107 lignes, 43 identiques |
| `inline_format` | `stories_helper.rb:62` / `opportunities_helper.rb:46` (`inline_format_opportunity`) | 18 lignes, **identiques à une classe CSS près** |
| Mapping d'émojis par titre | `stories_helper.rb:4` (`emoji_for`) / `opportunities_helper.rb:66` (`emoji_for_opportunity`) | 18 + 78 lignes |
| Vignette de secours | `home.html.erb:25` (`thumb_for`) / `opportunities/index.html.erb:5` (`thumb_for`) / `stories/index.html.erb:5` (`story_thumb`) | ×3 |
| Palette de catégories | `home.html.erb` ×4 (voir A13) | ×4 |

Les deux `inline_format` sont si proches que le `diff` complet tient en deux lignes :
le nom de la méthode, et `class="text-blue-600 hover:underline"` sur le lien. C'est
cette classe qui produit l'écart visible signalé en A14.

**Ce que ça produit.** Chaque correction de rendu est à faire deux fois, et l'oubli ne
se voit que sur l'un des deux types de contenu — donc tard. Les divergences de A14
sont exactement le résultat de corrections appliquées d'un seul côté.

Les trois `thumb_for` sont, elles, définies par un `def` à l'intérieur d'un template
ERB, ce qui les place sur `Object` (autre rapport, 3.6) : la troisième redéfinit
silencieusement la première.

**Effort** : 2 h pour n'avoir qu'un moteur de rendu et un `inline_format`. Les
`thumb_for` : 30 min.

---

### B4 — La page d'accueil fait 1 552 lignes, dont 73 % de CSS et de JavaScript

**Où** : `app/views/pages/home.html.erb`

| | lignes |
|---|---|
| `<style>` | 654 |
| `<script>` | 476 |
| logique Ruby en tête de fichier (l.3-79) | 77 |
| **balisage réel** | ~345 |

Le fichier contient la définition de quatre méthodes Ruby, six palettes de couleurs, la
totalité du CSS de la page, l'initialisation de Leaflet, le clustering, la logique de
filtrage, la géolocalisation et le rendu des popups.

Le tableau d'ensemble, sur les vues de plus de 150 lignes :

| Fichier | total | `<style>` | `<script>` | `style="..."` |
|---|---|---|---|---|
| `pages/home.html.erb` | 1552 | 654 | 476 | 7 |
| `pages/philosophie.html.erb` | 891 | 613 | 0 | 0 |
| `admin/stories/_form.html.erb` | 740 | 321 | 30 | 20 |
| `pages/presse.html.erb` | 646 | 453 | 0 | 0 |
| `opportunities/show.html.erb` | 631 | 178 | 61 | 6 |
| `pages/confidentialite.html.erb` | 623 | 365 | 0 | 0 |
| `admin/opportunities/_form.html.erb` | 547 | 135 | 0 | 24 |
| `pages/faq.html.erb` | 506 | 277 | 0 | 0 |
| `opportunities/index.html.erb` | 434 | 155 | 155 | 4 |
| `stories/show.html.erb` | 334 | 44 | 18 | **74** |

Au total **4 318 lignes de `<style>`** réparties dans les templates, en plus des
1 448 lignes de `application.css` et de Tailwind.

**Ce que ça produit.** Deux effets concrets, au-delà du confort de lecture :

- ce CSS est renvoyé au navigateur **à chaque chargement de page**, jamais mis en
  cache, et il n'est pas partagé entre pages ;
- une modification de style se cherche dans quatre endroits possibles (Tailwind,
  `application.css`, le `<style>` de la page, l'attribut `style=`), et la règle qui
  gagne dépend de l'ordre. `stories/show.html.erb` et ses 74 attributs `style=` en
  ligne sont, de fait, non modifiables autrement qu'un par un.

**Effort** : sortir le CSS de la page d'accueil vers un fichier : 1 h 30, sans risque
fonctionnel. Le reste se fait page par page, à l'occasion.

---

### B5 — `.container` est redéfini neuf fois, dont quatre sans portée

**Où** :

| Fichier:ligne | Portée | Largeur |
|---|---|---|
| `app/assets/stylesheets/application.css:40` | globale | 1140 px |
| `pages/home.html.erb:501` | `.home-ms .container` | 1280 px |
| `stories/index.html.erb:104` | `.stories-ms .container` | 1200 px |
| `opportunities/index.html.erb:131` | `.ops-ms .container` | 1200 px |
| `pages/sponsors.html.erb:184, 226, 399` | `.sp-* .container` | 1180 px |
| `layouts/admin.html.erb:13` | globale (layout admin) | 1200 px |
| **`pages/contact.html.erb:90`** | **globale** | ? |
| **`pages/presse.html.erb:203`** | **globale** | ? |
| **`pages/faq.html.erb:239`** | **globale** | ? |
| **`pages/confidentialite.html.erb:268`** | **globale** | ? |

Les cinq premières sont préfixées, donc sans effet de bord. Les quatre en gras ne le
sont pas : elles écrasent la règle globale de `application.css` pour toute la page.

**Ce que ça produit.** La largeur de la colonne de contenu change en naviguant :
accueil (1280) → FAQ (autre valeur) → Presse (autre valeur) → Contact (autre valeur).
Le contenu « saute » latéralement d'une page à l'autre. C'est le genre d'irrégularité
qu'on sent sans savoir la nommer.

`.btn`, `.markdown-content` et `.leaflet-container` sont dans le même cas : définis à
la fois dans `application.css` et dans des templates.

**Effort** : 30 min pour préfixer les quatre règles non portées.

---

### B6 — Une feuille de style de 327 lignes n'est chargée par aucune page

**Où** : `app/assets/stylesheets/stories.css` (327 lignes)

Le layout ne charge que deux feuilles
(`layouts/application.html.erb:34`) :

```erb
<%= stylesheet_link_tag "tailwind", "application", "data-turbo-track": "reload" %>
```

`stories.css` n'apparaît dans aucun `stylesheet_link_tag`. Elle est précompilée par
`manifest.js` (`link_directory ../stylesheets .css`) et jamais servie.

**Ce que ça produit.** Elle définit `.story-page .container.narrow` et d'autres règles
qui ressemblent fort à ce que `stories/show.html.erb` refait aujourd'hui avec ses 74
attributs `style=` en ligne. Autrement dit : le style de la page « histoire » a été
écrit une fois proprement, n'a jamais été branché, et a été refait à la main dans le
template.

Elle fausse aussi les recherches : chercher une règle CSS dans le projet la trouve, et
elle n'a aucun effet.

**Effort** : 5 min pour la brancher et voir ce qui se produit ; ou 2 min pour la
supprimer. À décider en la regardant.

---

### B7 — Deux vues d'opportunité de 282 et 8 lignes ne sont rendues par personne

**Où** :

- `app/views/opportunities/_form.html.erb` — 282 lignes. Les quatre `render "form"` du
  projet sont dans `admin/`, et pointent donc sur `admin/*/​_form`. Le formulaire public
  (`opportunities/new.html.erb`) contient son propre balisage. Ce partiel n'est appelé
  nulle part.
- `app/views/opportunities/edit.html.erb` — première ligne :
  `<!-- app/views/admin/opportunities/edit.html.erb -->`. C'est une copie de la vue
  d'admin, rangée dans le dossier public, où aucune route `edit` n'existe
  (`routes.rb:9`, `only: %i[index show new create]`).

**Ce que ça produit.** Une modification du formulaire d'opportunité se fait à tâtons :
trois fichiers candidats, dont deux morts, et celui qui est mort porte un en-tête qui
désigne un autre chemin. C'est exactement le genre de piège qui coûte une demi-heure à
chaque fois.

À rapprocher des neuf fichiers `.bak` suivis par git (autre rapport, 3.4), dont quatre
variantes de `opportunities/show.html.erb`.

**Effort** : 10 min pour vérifier et supprimer.

---

### B8 — Trois champs de statut pour une seule colonne

**Où** : `app/views/admin/stories/_form.html.erb:346-372`

```erb
<% if @story.respond_to?(:active) %>          … f.check_box :active
<% elsif @story.respond_to?(:is_active) %>    … f.check_box :is_active
<% elsif @story.respond_to?(:published) %>    … f.check_box :published
<% else %>  ℹ️ Cette story sera automatiquement publiée (pas de champ statut…)
```

Et `admin/stories_controller.rb:167` autorise les trois :
`:active, :is_active, :published`.

La base n'a qu'`is_active` (`db/schema.rb:148`). La deuxième branche est donc la seule
atteignable, et le message d'aide de la branche `else` — qui affirme qu'il n'y a pas de
champ statut — ne peut jamais s'afficher.

**Ce que ça produit.** Rien de cassé aujourd'hui : ça fonctionne. Mais c'est un
échafaudage défensif autour d'une hésitation de nommage qui n'a jamais été tranchée, et
il masque le comportement réel. Si une colonne `active` apparaît un jour, le formulaire
bascule silencieusement dessus et les histoires existantes deviennent invisibles.

Détail utile à connaître : `checked: @story.is_active != false` — sur une nouvelle
histoire, `is_active` vaut `nil`, donc la case est **précochée**. Une histoire créée
depuis l'admin est publiée par défaut ; une histoire reçue du formulaire public ne
l'est pas (`story.rb:66`). Deux comportements opposés, aucun n'est écrit quelque part.

**Effort** : 15 min pour ne garder que `is_active`, dans la vue et dans le `permit`.

---

### B9 — Le vocabulaire du code oblige à traduire mentalement

Détaillé dans la section **Vocabulaire** ci-dessous. Le coût pratique, ici : entre le
formulaire public (`content`, `name`, `email`), les colonnes (`body`, `author_name`,
`author_email`) et l'affichage (`chapo`, `contact_info`), la même donnée porte jusqu'à
trois noms sur son trajet. Le remapping se fait à la main dans
`stories_controller.rb:44-52`, dans un `tap` qui supprime et réaffecte des clés — le
passage le plus difficile à relire du contrôleur, et celui qu'on n'ose plus toucher.

**Effort** : voir la section dédiée.

---

## C. Cosmétique

- **Émojis divergents pour la même catégorie.** Bénévolat : 🤝 dans le formulaire
  public (`opportunities/new.html.erb:65`), ❤️ sur l'accueil (`home.html.erb:154`).
  Formation : 🎓 vs 📘. Rencontres : 👋 vs 👥. *5 min.*

- **Ordre des catégories.** `opportunity.rb:28` et le formulaire d'admin : bénévolat,
  formation, rencontres, entreprendre, écologiser. Les chips de l'accueil
  (`home.html.erb:154-159`) : bénévolat, écologiser, formation, rencontres,
  entreprendre. *2 min.*

- **`@journey_cards` ne couvre que quatre catégories sur cinq.**
  `pages_controller.rb:8-19` : « Je veux aider / apprendre / rencontrer /
  entreprendre ». `ecologiser`, ajouté plus tard, n'a jamais eu sa carte. Sans effet
  aujourd'hui puisque la variable n'est pas affichée (autre rapport, 2.5). *À traiter
  avec A4.*

- **`admin/stories/new.html.erb:4` affiche « Nouvelle story »** — le seul endroit de
  l'interface, publique ou admin, où le mot anglais apparaît en titre. Ailleurs :
  « Gestion des Stories » (`admin/stories/index.html.erb:4`) et « Import Story (bêta) »
  (`_form.html.erb:21`). *5 min.*

- **`app/views/admin/new.html.erb` est un fichier vide** rattaché à aucun contrôleur.
  *1 min.*

- **Le formulaire public d'histoire utilise `text_field` pour le téléphone**
  (`stories/new.html.erb:55`) là où les formulaires d'opportunité utilisent
  `telephone_field`. Pas de clavier numérique sur mobile. *2 min.*

---

## Vocabulaire : une chose, plusieurs noms

Réponse à la question 1. Quatre familles, par ordre de dégât.

### Famille 1 — Le récit d'une personne

**Sept désignations pour une seule chose**, plus deux homonymes qui désignent
autre chose.

| Terme | Où | Registre |
|---|---|---|
| « Belles Histoires » | `home.html.erb:212`, `stories/index.html.erb:27`, `faq.html.erb:104` | titre de rubrique |
| « Derniers témoignages » | `stories/index.html.erb:60` | titre de liste |
| « TÉMOIGNAGE » | `stories/index.html.erb:66`, `home.html.erb:225`, popup carte `home.html.erb:1182` | badge de vignette |
| « Témoignages » | `_navbar.html.erb:38` et `:119` | entrée de menu |
| « Partager un témoignage » | `_navbar.html.erb:57` et `:147` | bouton d'action |
| « Raconter mon histoire » | `stories/index.html.erb:35` | bouton d'action |
| « Votre Histoire 📖 » | `stories/new.html.erb:79` | titre de formulaire |
| `Story` / « story » | modèle, routes, `admin/stories/new.html.erb:4` | code + admin |

Et les deux homonymes qui n'en sont pas :

- **La section « Témoignages » de l'accueil** (`home.html.erb:277-340`) n'affiche
  aucune `Story` : ce sont quatre personnes écrites en dur dans le template (voir A8).
  Deux blocs distincts de la même page portent donc le mot « témoignage ».
- **Le champ « Citation / Témoignage » du formulaire d'opportunité**
  (`admin/opportunities/_form.html.erb:112`, `opportunities/_form.html.erb:62`) désigne
  les colonnes `quote` / `quote_author` d'une **opportunité**, pas une histoire.
- **La table `testimonials`** existe, est vide, et n'est référencée par aucun code
  (autre rapport, 3.2). Elle porte le nom que l'interface emploie le plus.

**Ce que ça produit.** Deux boutons différents (« Partager un témoignage » dans la
barre, « Raconter mon histoire » sur la page de liste) mènent au même formulaire ; le
visiteur peut croire qu'il y a deux dispositifs. L'entrée de menu « Témoignages »
mène — en principe — à une section de l'accueil qui n'affiche pas de `Story`. Et pour
vous, chercher « témoignage » dans le code donne quatre choses sans rapport.

**Ce que je retiendrais : « Belle histoire ».**
C'est le terme qui porte l'intention éditoriale du site, il est employé dans les
titres de rubrique et repris par la FAQ (`faq.html.erb:104` : « Les "Belles Histoires"
sont au cœur de Déclic »), et il se distingue naturellement du champ « Citation /
Témoignage » d'une opportunité. « Témoignage » est plus attendu mais il est déjà pris
trois fois. Il faudrait alors renommer côté visible — badge de vignette, entrée de
menu, bouton — et laisser `Story` tranquille dans le code : le coût d'un renommage de
modèle (routes, slugs, URL indexées) n'est pas justifié.

*Effort : 1 h pour les libellés visibles.*

---

### Famille 2 — La chose qu'on propose

| Terme | Où | Statut |
|---|---|---|
| « Opportunité » | modèle, routes, admin, la plupart des vues | dominant (73 occurrences) |
| « Initiative » | `opportunities/new.html.erb:15`, `merci.html.erb:50`, `show.html.erb:409`, `home.html.erb:247, 258, 268` | 13 occurrences |
| « Initiative » | popup carte `home.html.erb:1183` — libellé de la catégorie par défaut | **visible sur la carte** |
| « Proposition » | `merci.html.erb:45`, `faq.html.erb:94, 114`, `opportunity_proposal_mailer/proposal_email.html.erb:1` | 6 occurrences |
| « Mission » | `presse.html.erb:24` (« Notre mission ») | sens différent, pas de conflit |

**Ce que ça produit.** L'écart le plus net est sur le parcours de contribution : le
formulaire dit « Votre **initiative** locale peut inspirer », la page de remerciement
dit « Votre **proposition** a bien été reçue », et la FAQ parle de « proposition ».
Trois mots pour ce que le visiteur vient de faire.

Le cas de la carte est plus gênant que les autres : `default: { label: 'Initiative' }`
(`home.html.erb:1183`) est le libellé qui s'affiche dans le popup quand la catégorie
n'est pas reconnue — donc sur les fiches importées dont la catégorie ne fait pas partie
des cinq. Un visiteur voit alors une pastille « Initiative » qui ne correspond à aucun
filtre.

**Ce que je retiendrais : « opportunité » partout dans l'interface**, puisque le modèle,
les routes et l'admin sont déjà alignés dessus, **sauf sur le parcours de
contribution**, où « proposition » est plus juste : ce que le visiteur envoie n'est pas
encore une opportunité, c'est une proposition en attente de relecture — ce que le site
lui dit d'ailleurs. Le mot marque bien l'étape. « Initiative » n'apporte rien et
introduit une fausse catégorie sur la carte.

*Effort : 30 min.*

---

### Famille 3 — Où ça se passe

**Six colonnes pour une adresse**, sur `opportunities` :
`location`, `address`, `city`, `postal_code`, **`postcode`** (doublon mort),
`latitude`/`longitude`.

- `location` est le champ que le géocodeur lit (`opportunity.rb:33`), et c'est du texte
  libre.
- `address`, `city`, `postal_code` sont saisis par le formulaire public
  (`opportunities_controller.rb:56-58`), mais `city` n'a aucun champ dans le formulaire
  d'admin alors qu'il est affiché sur la fiche (`show.html.erb:250`).
- `postcode`, hérité de la migration initiale, n'est plus écrit par rien (autre
  rapport, 3.3).
- Le code commenté dans `opportunity.rb:129-135` montre la tentative abandonnée de
  composer `location` à partir des trois autres.

Côté vocabulaire visible : « Lieu » (colonnes d'admin), « Localisation » (section du
formulaire d'admin), « Adresse » (formulaire public), « Ville ». Ce sont des mots
justes pour des choses différentes — le désordre est dans le modèle, pas dans les
libellés.

**Ce que je retiendrais** : `location` comme unique champ de saisie côté admin, puisque
c'est le seul que le géocodage utilise, et `address` / `city` / `postal_code`
uniquement en réception du formulaire public. Rien à renommer, tout à documenter.

*Effort : 30 min pour ajouter un champ `city` à l'admin et une note. Le nettoyage de
`postcode` relève de l'autre rapport.*

---

### Famille 4 — Publié ou non

| Terme | Où |
|---|---|
| `is_active` | seule colonne réelle (`schema.rb:148` et `:66`) |
| `active` | scope `Story.active` / `Opportunity.active` ; case à cocher (`_form.html.erb:350`) ; `permit` |
| `published` | case à cocher (`_form.html.erb:366`) ; `permit` |
| « Statut » | libellé du champ |
| « ✅ Publié (visible sur le site) » | texte de la case |
| « Actif » / « Inactif » | colonne « Statut » des listes d'admin |
| `only_inactive` / `missing_coords` | filtres de `admin/opportunities_controller.rb:11-12` |

**Ce que je retiendrais : « publié / non publié »** côté interface — c'est le mot que
le formulaire emploie déjà et celui que la modération appelle naturellement — et
`is_active` seul côté code. Voir B8 pour la partie exécutable.

---

## Le modèle de données vu du produit

Réponse à la question 5.

### Ce que le site propose aujourd'hui

Deux choses, et une seule vraie différence entre elles : **une opportunité est une
invitation à faire quelque chose** (elle a un lieu, des dates, un contact, un appel à
l'action) ; **une histoire est un récit de ce que quelqu'un a fait** (elle a un
auteur, une date passée, un texte long).

Le découpage `Opportunity` / `Story` correspond donc bien à l'offre. Il n'y a pas de
problème de fond. Les frottements sont ailleurs — ils viennent tous de ce que les deux
modèles ont grandi **en parallèle sans jamais se regarder**.

### Frottement 1 — Deux modèles jumeaux, aucun code commun

Champs identiques de part et d'autre, avec des types ou des noms différents :

| Concept | `Opportunity` | `Story` |
|---|---|---|
| Coordonnées | `decimal(10,6)` | `float` |
| Image principale | `has_one_attached :image` + `image_url` | identique |
| Photos inline | `inline_image_1..3` + `inline_caption_1..3` | identique |
| Marqueur inline | `<!-- IMAGE_1 -->` | `___INLINE_PHOTO_1_PLACEHOLDER___` |
| Slug | FriendlyId (`slugged, finders`) | `title.parameterize` à la main (`story.rb:63`) |
| Statut | `is_active` | `is_active` |
| Source | `source_name` + `source_url` | `source_name` + `source_url` |
| Rendu du corps | `render_opportunity_body` | `render_story_body` |
| Vignette de secours | `hero_image_url` | `hero_image_url` |

Rien de tout cela n'est mutualisé : ni concern, ni module, ni partiel commun. D'où A6,
A14 et B3, qui sont trois symptômes du même fait.

Deux conséquences directes visibles :

- **Le slug.** `Opportunity` utilise FriendlyId, qui gère l'unicité et l'historique.
  `Story` fabrique le sien avec `parameterize` sans index unique (autre rapport, 2.6).
  Deux histoires de même titre produisent le même slug, et `find_by!(slug:)`
  (`stories_controller.rb:11`) en renvoie une au hasard.
- **La précision des coordonnées.** `decimal(10,6)` d'un côté, `float` de l'autre. Sur
  une carte qui affiche les deux ensemble (`home.html.erb:1343`), c'est sans effet
  visible, mais c'est un choix pris deux fois sans le savoir.

### Frottement 2 — `Testimonial` occupe le nom dont l'interface a besoin

La table existe depuis le 24 août 2025 (`create_testimonials`), n'a jamais été
utilisée, a reçu deux migrations qui s'annulent, et porte le mot que l'interface
emploie partout (voir Famille 1). Pendant ce temps, les « témoignages » de la page
d'accueil sont quatre entrées écrites en dur dans le template.

C'est le point où le modèle ment sur le produit : il existe une table `testimonials`,
et il n'y a pas de témoignages en base ; il existe des témoignages à l'écran, et ils ne
viennent pas de la base.

### Frottement 3 — « Histoires » est présentée comme une sixième catégorie

`home.html.erb:159` place « ✨ Belles histoires » dans la même barre de filtres que les
cinq catégories d'opportunités, et `:1342` force `s.category = 'histoires'` sur les
histoires avant de les fusionner avec les opportunités dans un tableau unique.

Du point de vue du visiteur c'est défendable — il filtre « ce qu'il veut voir sur la
carte », pas « des entités ». Mais cela crée une catégorie fantôme qui n'existe ni dans
`Opportunity::CATEGORIES` (`opportunity.rb:28`) ni dans aucun formulaire, et qui doit
être traitée à part dans quatre endroits du JavaScript (`:1139`, `:1154`, `:1189`,
`:1342`).

C'est aussi ce qui explique A13 : « histoires » a besoin d'une couleur et d'un libellé
dans chacune des quatre palettes, et n'a jamais eu la même.

### Ce que j'en conclus

Le découpage à deux modèles est le bon. Ce qui manque, c'est **une couche partagée** —
images inline, rendu du corps, slug, statut, source — que les deux modèles utiliseraient
au lieu de la réimplémenter. C'est le seul endroit de cet audit où j'aurais une
suggestion de structure, et je m'y tiens parce que le coût actuel est mesurable : toute
correction de rendu se paie deux fois, et l'oubli produit les écarts visibles de A14.

`Testimonial` est à supprimer, sans hésitation : rien ne l'utilise, et son nom gêne.

---

## État du chantier

Réponse à la question 4.

### Le rythme

Commits sur `main`, par mois :

```
2025-08   ████ 4
2025-09   ███████████████████████████████████ 35
2025-10   █████████████████████████████████████ 37
2025-11   █████████████████████████████████████████ 41
2025-12   ██████████████████████████████████████████████████ 50
2026-01   ███████████████████████████████████████████████████████████ 59
2026-02   ████████████████ 16
2026-03   ███████████████████████████████████████████████ 47
2026-04   █████████████████████████████████████████ 41
2026-05   ██████ 6
2026-06   ███████ 7
2026-07   0
2026-08   0
2026-09   █ 1
```

Deux creux : février 2026, puis un arrêt à partir de mai. Le chantier en cours
(branche `veille-belles-histoires`, six commits non fusionnés) reprend en septembre.

### À finir

| Quoi | Où en c'est | Effort |
|---|---|---|
| **Le « parcours »** | Route déclarée, contrôleur qui ignore le paramètre, vue à moitié prête, `@journey_cards` construit et jamais affiché, entrée de menu sur ancre morte. Quatre amorces, zéro fonctionnement. C'est la seule fonctionnalité inachevée qui ait une vraie valeur produit : c'est l'entrée « je ne sais pas ce que je cherche ». | 2 h |
| **Le CTA des opportunités** (A9) | Colonnes + affichage faits, saisie manquante. À dix minutes d'être utile. | 20 min |
| **Les dates des opportunités** (A10) | Saisie faite, affichage manquant, et sur les mauvaises colonnes. | 1 h 30 |
| **Le mode hors ligne** (A12) | Service worker complet et correct, vue `offline` écrite. Il manque une route. | 20 min |
| **Les coordonnées des histoires** (B1) | Collecte faite, affichage manquant, ressaisie manuelle en attendant. | 45 min |
| **`stories.css`** (B6) | 327 lignes écrites, jamais branchées. À regarder avant de trancher. | 15 min |

### À supprimer

| Quoi | Pourquoi |
|---|---|
| **Les trois articles de presse fictifs** (A1) | Le message honnête juste en dessous suffit. |
| **`Testimonial`** — modèle, table, 3 migrations, fixture, test | Jamais utilisé depuis août 2025, et son nom gêne l'interface. |
| **Le sous-système d'ingestion** — `Ingestors`, `RssFetcher`, `IcsFetcher`, `RawMapper`, `Source`, `RawIngestion`, `lib/tasks/sources.rake` | Les tables n'existent pas sur `main` (autre rapport, 3.1). Rien touché depuis septembre 2025. Le chantier veille en cours reprend le même sujet autrement : garder les deux serait entretenir deux réponses à une seule question. |
| **`app/views/opportunities/_form.html.erb`** (282 l.) et **`edit.html.erb`** (B7) | Rendues par personne, et la seconde porte l'en-tête d'un autre fichier. |
| **Les 9 fichiers `.bak`** | Dont 4 variantes de `opportunities/show.html.erb`. Ils faussent toute recherche dans le code. |
| **`app/views/admin/new.html.erb`** | Fichier vide. |
| **`app/views/pwa/service-worker.js` et `manifest.json.erb`** (A12) | Gabarit Rails, doublons de ceux qui servent réellement. |
| **`app/views/layouts/application_noturbo.html.erb`** | Jamais référencé. |
| **`lib/tasks/check_placeholders.rb`** | Un `.rb` dans `lib/tasks/`, que Rails ne charge pas (autre rapport, 3.4). Créé le 31/03/2026, jamais exécutable. |

### À décider, pas à corriger

- **Les quatre témoignages de l'accueil** (A8) : contenus fictifs illustrés par des
  photos de personnes réelles. Le bug (deux photos interverties) se corrige en 5 min ;
  la question de fond est de savoir si ces témoignages restent en attendant de vrais.
- **`scripts/` et `collector/`** : scrapers Python et Ruby hors application, dernière
  activité mars 2026. Ils ne gênent rien mais ne sont pas exécutés par le site. Leur
  sort dépend de ce que devient le chantier veille.

---

## Récapitulatif

| # | Point | Effort |
|---|---|---|
| **A1** | Trois articles de presse fictifs attribués à des médias réels | 15 min |
| **A2** | Messages d'erreur en anglais sur les formulaires publics | 30 min |
| **A3** | Deux des quatre liens du menu mènent à des ancres inexistantes | 5 min |
| **A4** | `/parcours/:category` n'applique pas le filtre | 20 min |
| **A5** | Pages légales contradictoires et inexactes | 1 h 30 |
| **A6** | Deux syntaxes de marqueurs d'images inline | 45 min |
| **A7** | 100+ vs 200+ opportunités selon la page | 20 min |
| **A8** | Photos et prénoms intervertis dans les témoignages | 5 min |
| **A9** | Le bouton « Passer à l'action » ne peut pas s'afficher | 20 min |
| **A10** | Dates et durées saisies, jamais affichées | 30 min |
| **A11** | Six liens `href="#"` | 10 min |
| **A12** | Le mode hors ligne de la PWA ne fonctionne pas | 20 min |
| **A13** | Quatre palettes et deux libellés divergents par catégorie | 30 min |
| **A14** | Deux moteurs de rendu au comportement différent | 1 h |
| **B1** | Coordonnées à ressaisir à la main | 45 min |
| **B2** | Colonne « Date » de l'admin = date de saisie | 20 min |
| **B3** | Code de rendu dupliqué (2 moteurs, 2 `inline_format`, 3 `thumb_for`) | 2 h 30 |
| **B4** | 4 318 lignes de CSS dans les templates | 1 h 30 |
| **B5** | `.container` redéfini 9 fois, 4 sans portée | 30 min |
| **B6** | `stories.css` (327 l.) jamais chargée | 15 min |
| **B7** | Deux vues d'opportunité orphelines | 10 min |
| **B8** | Trois champs de statut pour une colonne | 15 min |
| **C** | Cosmétique (6 points) | 20 min |
| **Vocab.** | Alignement des libellés visibles (4 familles) | 2 h |

Section A : environ **6 h 40**. Les quatre premiers points — A1, A2, A3, A4 — pèsent
1 h 10 à eux quatre et sont ceux qu'un visiteur rencontre le plus vite.
