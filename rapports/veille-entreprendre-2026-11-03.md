# Veille « Entreprendre » : structures d'accompagnement du Grand Nancy, diagnostic

Date : 03/11/2026. Diagnostic seul, aucun code touché. Requêtes faites le 03/11 avec l'identité de la veille (`DeclicVeille/1.0 (+https://declic.site)`), comme `Veille::Http`.

**Limites de l'enquête.** Le site de la CCI (nancy.cci.fr, et cci.fr) répond 403 avec un défi Cloudflare, robots.txt compris. Je n'ai donc lu ni son agenda ni ses mentions légales. Ce que j'en dis vient de la presse. Je n'ai pas ouvert les pages LinkedIn ni Facebook (même règle que le diagnostic du 02/11). Initiative Grand Nancy et Réseau Entreprendre Lorraine n'ont été vus qu'à travers la presse, pas sur leur site.

## Synthèse

| Structure | Source exploitable | Conditions de réutilisation | Activité récente | Recommandation |
|---|---|---|---|---|
| **Grand Nancy Innovation (GNI)** | **API WordPress publique** `/wp-json/wp/v2/event` (47 événements), `robots.txt` permissif. Le RSS existe mais est vide. | **Restrictives** : reproduction interdite sans autorisation écrite | Rien de neuf depuis le **08/06/2026** | **Demander l'autorisation**, puis automatiser (½ à 1 jour). En attendant : saisie manuelle |
| **CCI Grand Nancy Métropole Meurthe-et-Moselle** | **Aucune** : Cloudflare bloque tout robot, y compris la lecture du robots.txt | Non lisibles (403) | Gros événements annuels connus par la presse | **Semi-manuel**, 2 ou 3 événements par an |
| **Alexis Grand Est** | Site HTML statique ; agenda = **2 PDF annuels**. Pas de RSS, pas d'API | **Restrictives** (CGU art. 9 : poursuites en cas de reproduction) | Calendrier 2026 publié, à jour | **Semi-manuel** : deux saisies par an, avec des fiches permanentes |
| **Transentreprise** (déjà branché : `Connectors::Transentreprise`) | RSS `/rss/offre` + listes HTML statiques filtrables (`…/Meurthe-et-Moselle-54/Arrond-Nancy-3`) ; `robots.txt` permissif | **Interdiction expresse** de l'extraction automatisée ET de la réutilisation des flux RSS d'annonces | ~1 offre nouvelle en 54 toutes les 2 semaines | **Retirer le connecteur du quotidien** ; lien permanent ou convention |
| OpenAgenda « Nancy Innovation » | API OpenAgenda | – | **0 événement** | Ne vaut pas le coup |
| Bpifrance Création (agenda national) | HTML filtrable par région | – | 1 seul événement dans le Grand Est (Colmar) | Ne vaut pas le coup |
| PeeL (Pépite Lorraine, étudiants) | RSS WordPress ouvert | non relu | Dernier article : 21/03/2024 | Ne vaut pas le coup |
| Agenda Grand Nancy (déjà branché) | API | – | Aucun événement « entreprendre » sur 343 | Ne couvre pas ce créneau |

**Conclusion.** Aucune des trois structures ne publie un flux à la fois ouvert techniquement et libre de droits. **GNI est la seule où une intégration automatique est techniquement prête**, mais ses mentions légales l'interdisent sans accord écrit, et son agenda ne bouge plus depuis cinq mois. **Alerte : Transentreprise, déjà lu chaque jour par la veille en prod, interdit désormais explicitement ce que fait le connecteur** (voir §4). Pour la catégorie Entreprendre, le meilleur rendement à court terme vient de **fiches permanentes** sur les rendez-vous récurrents (pitch nights, réunions d'information mensuelles, Matinales), saisies à la main deux fois par an. Il faut compléter par une demande d'autorisation à GNI, qui est la seule source à forte cadence potentielle.

## 1. Grand Nancy Innovation

- **Site** : `https://grandnancy-innovation.eu` (WordPress 7.1, refait par l'agence Nooki, éditeur : SEM Henri Poincaré). Agenda : `/nos-events/`, un calendrier en JavaScript ; chaque événement a une page `/evenements/<slug>/`. Adresse : bâtiment ORBOR, 5 rue Jacques Villermaux, Nancy.
- **`robots.txt`** : n'interdit que `/wp-admin/`.
- **Flux** :
  - `/feed/` répond, mais **vide** : le site n'a aucun article (`/wp/v2/posts` : 0).
  - **`/wp-json/wp/v2/event?per_page=100`** : API REST publique, 47 événements (titre, contenu HTML, lien, image), et aussi `/wp/v2/appel_projet` (1 appel à projets).
  - **Pas de champ date structuré** (ni ACF ni meta exposés) : la date n'est que dans le titre (« Pitch Night | Jeudi 28 mai | 17H – 19H ») ou le texte, souvent sans l'année. `AiEnricher` sait l'extraire (date du jour et date de publication en contexte, garde-fou `date_plausible`).
- **Mentions légales** (`/mentions-legales/`) : « Toute reproduction, représentation, modification, publication ou adaptation totale ou partielle du site ou de son contenu, par quelque procédé que ce soit, est interdite sans autorisation écrite préalable, sauf utilisation à des fins strictement personnelles. » C'est le même cas que les 6 communes restrictives du 02/11.
- **Type d'événements** : directement dans la cible Entreprendre. Pitch Night (presque tous les mois), Spark Sessions (ateliers : banque, pacte d'associés, juridique, cybersécurité, branding), Midis de l'entrepreneuriat (IA Act…), masterclasses (forme juridique, trouver des clients), Cercle des startups, webinaires (propriété intellectuelle, marketing), Cyberday, networking deeptech, apéros ORBOR. Plusieurs sont ouverts aux porteurs de projet débutants, d'autres réservés aux startups accompagnées.
- **Cadence** : 36 événements versés le 15/04/2026 (reprise de l'ancien site, événements 2025 et début 2026), 10 le 08/06/2026 (mai-juin), **plus rien depuis**. Il y avait environ 4 à 6 événements par mois au printemps. L'agenda en ligne semble à l'abandon, ou alimenté ailleurs (LinkedIn, newsletter). L'OpenAgenda « Nancy Innovation » (uid 93181283) que GNI avait lancé est **vide**.
- **Déjà dans Déclic** : la fiche 1849 « La Pitch Night — Grand Nancy Innovation » (saisie utilisateur, 25/06).

**Recommandation : demander une autorisation écrite** à GNI (structure publique de la Métropole, qui a intérêt à être relayée ; Nooki, qui a fait le site, est déjà une Belle Histoire de Déclic). Si l'accord arrive et que l'agenda revit, il faut un connecteur `Connectors::GrandNancyInnovation` qui lit l'API JSON, sur le modèle d'`AgendaNancy` : **½ à 1 jour** avec les tests (une requête, filtre sur la date de modification, `category_hint: "entreprendre"`, commune Nancy, dates laissées à l'IA). En attendant : **fiches permanentes** « Pitch Night GNI » et « Spark Sessions GNI » (`schedule_text` + lien vers `/nos-events/`), ce qui ne reprend aucun contenu.

## 2. CCI Grand Nancy Métropole Meurthe-et-Moselle (CCI 54)

- **Site** : `https://www.nancy.cci.fr`. **Tout répond 403 derrière un défi Cloudflare** (« Just a moment… ») : accueil, `/agenda`, `/robots.txt`, `/rss.xml`, et aussi `www.cci.fr`. `Veille::Http` refuse toute URL dont le robots.txt est illisible : **aucune lecture automatique n'est possible**, et contourner le défi est exclu. WebFetch échoue aussi (403).
- **Mentions légales** : non lues (403).
- **Événements connus par la presse** (La Gazette France, Le Journal des Entreprises) :
  - **Nuit de la Création** (1ʳᵉ édition le 08/10/2026 au Pala V à Laxou, concours de pitch ; remplace le Salon GO, dont la dernière édition a eu lieu le 26/11/2025) ;
  - **Repreneuriales** (transmission, avec Bpifrance et Réseau Entreprendre) ;
  - **formation « 5 jours pour entreprendre »** (session de juin 2026) ;
  - réunions d'information création-reprise, Nuit du Numérique, « Rendez-vous territoriaux ».
- **Pertinence** : forte pour Entreprendre, mais **peu d'événements publics par an** (quelques grands rendez-vous et des sessions de formation payantes).

**Recommandation : semi-manuel.** Les grands rendez-vous passent dans la presse locale. Le circuit existant `/admin/veille/presse` (geste « Retenir ») suffit, avec une saisie annuelle des dates. **Effort : nul côté code.** Une automatisation ne serait possible que si la CCI fournissait un flux ou levait le blocage, ce qu'on peut leur demander.

## 3. Alexis Grand Est

- **Site** : `https://www.alexis.fr` (HTML statique, « page mise à jour le 07/01/2026 »). Siège : 5 rue Alfred Kastler, Maxéville. Couveuse : `grand-test.fr`. Formations : `formations.ese.alexis.fr`.
- **`robots.txt`** : absent (404), ce que `Veille::Http` traite comme une autorisation.
- **Flux** : ni RSS ni API. L'agenda tient en **deux PDF annuels** liés depuis l'accueil :
  - `images/PDF/2026_Calendrier_Matinales_Experts_NancyMetz.pdf` : **Matinales Experts**, le vendredi de 10 h à 12 h à Maxéville, environ 20 dates par an à Nancy (loi de finances, facture électronique, protection du dirigeant, financement, paiements…), chacune animée par un partenaire privé (CIC, BPALC, Crédit Agricole, ACORIS, AREAS, Sadec Akelys, Abby). Prochaines : 06/11, 20/11, 04/12.
  - `grand-test.fr/pdf/Plaquettereuinfo2026.pdf` : **réunions d'information de la couveuse Grand Test** (« tester son activité sans immatriculation »), un jeudi par mois de 9 h à 12 h, à Maxéville ou en visio. Prochaines : 05/11, 03/12.
  - Page `historique_actualites_prgrm.html` : figée sur 2023-2024 (afterworks, soirées pitch, boutiques éphémères, concours Trajectoires).
- **CGU** (`cgpcgu/cgu.pdf`, art. 9) : textes, documents téléchargeables et bases de données sont la « propriété exclusive » d'Alexis. Toute reproduction sans autorisation « sera immédiatement poursuivie » (contrefaçon, concurrence déloyale). Le ton est plus dur que chez GNI.
- **Pertinence** :
  - les **réunions Grand Test** sont très en phase avec Déclic (premier pas, gratuit, ouvert à tous) ;
  - les **Matinales** sont utiles mais déjà orientées jeunes dirigeants, avec une part commerciale (chaque séance est portée par une banque ou un assureur) ;
  - le **concours Trajectoires** est annuel (fiche 1124 en prod).

**Recommandation : semi-manuel, sans code.** Deux PDF par an, au rythme connu (janvier) : il ne faut **pas** écrire de lecteur de PDF. Je propose **une fiche permanente « Réunion d'information couveuse Grand Test »** (« un jeudi par mois, 9 h-12 h, Maxéville », inscription contact@alexis.fr). Le même modèle peut servir pour **une fiche « Matinales Experts »**. Ce sont des faits (dates, lieu, contact) réécrits par nous, pas une reprise du contenu. **Effort : environ 30 minutes par an.**

## 4. Transentreprise (ajout du 03/11)

Plateforme nationale de cession-reprise, éditée par la **CCI de région Auvergne-Rhône-Alpes** pour le réseau des CCI et CMA. **Déjà intégrée** : `app/services/veille/connectors/transentreprise.rb` lit `/rss/offre` et garde les liens contenant `/meurthe-et-moselle/`. Elle est dans `Runner::QUOTIDIEN`, donc active en prod.

- **Filtre par département** : oui, par l'URL, sur des pages de liste en **HTML rendu côté serveur** (lisible sans JavaScript, 25 liens d'annonce par page, pagination `/liste/2`). Exemples :
  - département : `https://www.transentreprise.com/offres/liste/1/Lorraine-LOR/Meurthe-et-Moselle-54` (71 offres affichées le 03/11) ;
  - arrondissement de Nancy : `…/Meurthe-et-Moselle-54/Arrond-Nancy-3` ; il existe aussi Briey-1, Lunéville-2 et Toul-4 ;
  - variantes `…/difficulte/…` (entreprises en difficulté) et `…/locaux/…`.

  Il n'y a pas de filtre par code postal ni par commune : l'arrondissement de Nancy dépasse la Métropole. Le flux RSS, lui, **n'a pas de filtre** : il est national et contient « les offres de la semaine » (84 items le 03/11, publiés du 28/10 au 03/11, 8 dans le Grand Est, **0 en Meurthe-et-Moselle**).
- **`robots.txt`** : n'interdit ni `/rss/` ni `/offres/liste/` ni `/offres/fiche/` (seulement mini-fiches, favoris, partage, `/ajax/`, `/admin`…). Il déclare un sitemap (`/sitemap/offre.xml` : 7 170 annonces, dont 66 en 54).
- **API** : aucune trouvée. Il existe aussi des flux RSS `/rss/actus` et `/rss/temoignages`.
- **Mentions légales** (`/information/mentions`) : une section entière, **« Interdiction de reproduction, d'extraction automatisée et de réutilisation des flux RSS relatifs aux annonces »**. Sans autorisation écrite préalable, il est interdit :
  - de « reproduire, extraire, collecter, stocker, indexer ou exploiter […] les contenus, données ou annonces […] y compris via des outils automatisés » ;
  - de faire du scraping ou du crawling, ou d'utiliser des robots ;
  - de « réutiliser, diffuser, republier ou agréger […] les flux RSS relatifs aux annonces […] sur tout autre site ».

  « Les flux RSS sont destinés à un usage strictement personnel et privé. » L'autorisation passe par une **convention spécifique**, que l'éditeur peut refuser sans motif. Les sanctions annoncées : mise en demeure, contrefaçon, droit des bases de données, parasitisme ; l'éditeur prévient aussi qu'il peut bloquer les IP. **C'est plus explicite que L'Est Républicain**, et cela vise précisément ce que fait notre connecteur. Le `robots.txt` permissif ne change rien : `Veille::Http` le respecte, mais les CGU s'appliquent en plus.
- **Fréquence en Meurthe-et-Moselle** : les identifiants d'annonce sont croissants. Parmi les ~960 annonces nationales publiées sur les ~10 dernières semaines (identifiants ≥ 266000), **5 sont en Meurthe-et-Moselle**, soit environ **une tous les 15 jours**. Un peu plus de la moitié sont dans l'arrondissement de Nancy (37 sur 66 du stock). C'est une estimation par les identifiants, pas par des dates publiées. Le stock en 54 : 66 annonces (arrondissement de Nancy 37, Lunéville 7, Briey 7, Toul 5, sans arrondissement 10). Types : bar-tabac, café-bar, institut de beauté, boulangerie, mécanique industrielle, réfrigération…
- **Effet réel du connecteur en prod** : **0 candidat `transentreprise` créé** à ce jour. Rien n'a donc été republié sur Déclic. Deux écarts techniques au passage, désormais secondaires :
  - les liens actuels finissent par `/meurthe-et-moselle/arrond-nancy` alors que le code attend `arr-de-…` ou `…-et-arrondissement` (les tests figent l'ancien format) : la commune n'est donc pas déduite de l'arrondissement ;
  - les annonces sans arrondissement (`…/meurthe-et-moselle` sans `/` final, 10 sur 66) sont écartées par le filtre `include?("/meurthe-et-moselle/")`.
- **Pertinence pour Déclic** : réelle mais étroite. Reprendre un commerce est bien une manière d'« entreprendre », mais avec moins d'une annonce par mois dans la Métropole, chacune pour un public très ciblé (des repreneurs avec un apport). Cela ne nourrit pas la carte.

**Recommandation.**
1. **Retirer `Transentreprise` de `Runner::QUOTIDIEN` au prochain déploiement** (une ligne et son test ; je ne l'ai pas fait, consigne « pas de code »). Le risque juridique dépasse le gain : aucune fiche produite à ce jour. Il faudra aussi corriger `docs/veille-auto.md`, qui présente la source comme « officielle ».
2. À la place, **une fiche permanente** « Reprendre une entreprise près de Nancy » qui renvoie vers la liste filtrée `…/Meurthe-et-Moselle-54/Arrond-Nancy-3`. Un lien ne reproduit rien. On peut y ajouter les Repreneuriales de la CCI et l'accompagnement à la reprise d'Alexis. **Effort : 15 minutes.**
3. Si l'on tient au flux : **demande de convention** à contact@transentreprise.com (affichage titre + lien, commune, sans le texte de l'annonce). Ensuite, rebrancher le connecteur avec les deux correctifs ci-dessus : ½ jour avec les tests.

## 5. Autres pistes repérées

- **Initiative Grand Nancy** (prêts d'honneur) et **Réseau Entreprendre Lorraine** (5 rue Jacques Villermaux, comme ORBOR) : leur métier est le financement et le parrainage, avec peu d'événements publics (soirée annuelle, speed-dating de parrainage). Je n'ai pas trouvé leur agenda. À traiter par une **fiche permanente** chacun (« obtenir un prêt d'honneur »), pas par une veille.
- **PeeL** (Pépite Lorraine, `peel.univ-lorraine.fr`) : RSS ouvert, mais rien publié depuis mars 2024. À écarter.
- **Bpifrance Création** (agenda national, `bpifrance-creation.fr/entrepreneur/evenements`) : `robots.txt` permissif, filtre par région, mais un seul événement dans le Grand Est (Colmar). À écarter.
- **OpenAgenda « Nancy Innovation »** : vide (`events.v2.json` : total 0). À recontrôler si GNI le relance.
- **Agenda Grand Nancy** (déjà branché) : 343 événements, aucun sur l'entrepreneuriat (aucune rubrique « économie »). Ce créneau n'est pas couvert aujourd'hui.

## 6. Ordre proposé

0. **Transentreprise : sortir le connecteur du passage quotidien** (§4), avant le prochain `rake veille:quotidien` si possible.
1. **Tout de suite, sans code** : fiches permanentes Entreprendre (couveuse Grand Test, Matinales Alexis, Pitch Night et Spark Sessions GNI, prêts d'honneur Initiative et Réseau Entreprendre), plus les dates CCI repérées dans la presse. C'est une tâche de saisie (Sonnet suffit).
2. **Courriel à GNI** : demande d'autorisation de reprise de l'agenda (titre, date, lien vers leur page), en signalant au passage que leur agenda en ligne n'est plus alimenté depuis juin.
3. **Si GNI accepte et republie** : connecteur sur `/wp-json/wp/v2/event`, ½ à 1 jour, dans `Runner::QUOTIDIEN`, avec une marque d'autorisation comme `autorisee_par_decision` pour les communes.
4. CCI et Alexis : leur demander à l'occasion un flux (RSS ou iCal). Sinon, on garde le semi-manuel.

## Sources

- Grand Nancy Innovation : https://grandnancy-innovation.eu/nos-events/, https://grandnancy-innovation.eu/wp-json/wp/v2/event, https://grandnancy-innovation.eu/mentions-legales/, https://openagenda.com/fr/nancy-innovation
- Alexis Grand Est : https://www.alexis.fr/, https://www.alexis.fr/images/PDF/2026_Calendrier_Matinales_Experts_NancyMetz.pdf, https://www.grand-test.fr/pdf/Plaquettereuinfo2026.pdf, https://www.alexis.fr/cgpcgu/cgu.pdf
- CCI 54 (presse) : https://www.lagazettefrance.fr/article/la-nuit-de-la-creation-investit-le-pala-v-a-laxou-ce-8-octobre, https://www.lagazettefrance.fr/article/transmission-d-entreprise-les-repreneuriales-2026-s-installe-a-nancy, https://www.lagazettefrance.fr/article/nancy-la-cci-forme-les-porteurs-de-projet-a-la-creation-d-entreprise, https://www.lejournaldesentreprises.com/breve/la-cci-de-meurthe-et-moselle-lance-sa-premiere-nuit-du-numerique-nancy-2144703
- Transentreprise : https://www.transentreprise.com/information/mentions, https://www.transentreprise.com/robots.txt, https://www.transentreprise.com/rss/offre, https://www.transentreprise.com/sitemap/offre.xml, https://www.transentreprise.com/offres/liste/1/Lorraine-LOR/Meurthe-et-Moselle-54
- Autres : https://www.lejournaldesentreprises.com/article/grand-nancy-innovation-veut-devenir-le-superconnecteur-de-la-metropole-329984, https://bpifrance-creation.fr/entrepreneur/evenements, https://peel.univ-lorraine.fr/feed/
