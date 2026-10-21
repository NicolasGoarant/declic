# Calque « vivants » sur /labo/diorama (20/10/2026)

Planche : `docs/maquettes/vivants-labo-diorama/planche-avant-apres.webp` (place Stanislas aux niveaux 8 et 9, bassin du canal
au niveau 8 ; 1280 × 800, dpr 1, horloge figée à 120 s). Captures pleines : `stanislas-z8-{avant,apres}.webp`.

## Ce qui est porté

- `app/javascript/diorama/vivants.js` : portage du lecteur de la démo nancy-3d
  (`rapports/animations-v1/vivants-demo/index.html`, commit `ddc2ae8`), mode « itinéraires raccordés », réglages repris tels quels :
  - **vélos** : densité ×5 (20 par km et par sens sur piste, 15 sur bande), modèle `velo-detaille`, 10 px g ≤ 2,4, dès le niveau 8 ;
  - **piétons** : 8 px g ≤ 2, dès le niveau 8, foulée de 0,7 m ;
  - **voitures** : 10 px g ≤ 1,5, dès le niveau 7 ;
  - échelle ×1,6, pyramide de sprites pré-réduits, occlusion par colonnes (méthode « clip ») sur la propriété `propriete-toits-v1`,
    toile dimensionnée au pixel d'appareil (correctif du dpr 0,8).
- Une toile à part, posée juste après celle des dalles (sous le HUD et les boutons) : le chargement et le dessin des dalles ne changent pas.
- Activation : `?vivants=1` seulement. Une case « vivants » apparaît alors dans le HUD pour couper ou relancer le calque.
  Crochets : `?vivants-t=S` (horloge figée), `?vivants-densite-velo=P,B` (témoin, par exemple 16,12).
- Côté Rails : `DioramaTuiles::VIVANTS = "vivants-v1"` (nom de jeu proposé par nancy-3d) et `DIORAMA_VIVANTS_URL`, sur le modèle des bateaux.

## Vérifications

- Sans paramètre, la page est **identique au pixel près** à `HEAD` (Stanislas, niveaux 8 et 9, Chromium 1280 × 800).
  Calque coupé par la case : seule la ligne ajoutée au HUD diffère.
- Stanislas niveau 8 : 145 piétons, 2 vélos, 2 voitures, 2,7 à 3,8 ms par image. Bassin du canal (19000, 9200) niveau 8 :
  365 piétons, 63 vélos, 25 voitures, 4,1 ms. Peu de vélos à Stanislas, comme le relevait nancy-3d (§ 15 : 3,88 par image au niveau 8,
  0,08 au niveau 9) : le réseau cyclable passe ailleurs.
- `bin/rails test` : 123 verts (deux nouveaux tests).

## Ce qui est laissé de côté

- **Rien n'est publié.** Le jeu `vivants-v1` n'existe pas sur R2 : sans `DIORAMA_VIVANTS_URL`, `?vivants=1` affiche « indisponibles »
  et la page continue de fonctionner. Le paquet de nancy-3d (`paquet-v1`) n'a ni vélos ni bus : pour la vérification, un paquet LOCAL
  a été composé à partir des fichiers de la démo (calques `calques-50/{vehicules,pietons,velos}.json`, `repere.json`, atlas et
  pyramide de sprites, modèles filtrés), et servi en CORS. Avant toute publication, il faut trancher entre un jeu séparé et un
  `mobiles-v7` (`rapport-paquet-vivants-v1.md`).
- **Bus et trolleybus** : en production depuis le 21/10 (v361, `vivants-v2`, dernières sections).
- **Correctif des toits jv2** (`occlusion-toits-jv2.json`) : il ne vaut que pour le style jeu-video-v2, alors que /labo/diorama affiche toits-v1.
- **Neige, nuit, fenêtres** (vivant jv2) : ce sont des recettes de rendu des dalles du style jeu-video-v2, pas un calque animé.
  Elles ne sont pas reportées (voir NOTES, réglages du 30/09). /labo/diorama n'a pas d'ambiances.
- Points ouverts : les pins d'opportunités sont dessinés sur la toile des dalles, donc **sous** les vivants. Rien n'est sous
  `prefers-reduced-motion`. Il n'existe pas de chargement différé : environ 13 Mo de données et la préparation des calques au chargement,
  ce que le rapport du paquet chiffre à environ 0,9 s de fil principal sous Node.

## Seuils et « niveau » du HUD (20/10, après v357)

« 0 vélos, 0 piétons, 41 voitures » en production à Stanislas : ce n'est ni un cache ni un fichier manquant (les 9 fichiers lus
répondent en 200, sans erreur). Le « niveau » de la ligne des dalles est celui des dalles chargées :
`ceil(8 + log2(s × dpr) − 0,25)`, plafonné à 8. Il vaut donc 8 dès ×0,42 à dpr 2 et dès ×0,84 à dpr 1. Or les vivants suivent
l'échelle : voitures dès ×0,5, piétons et vélos dès ×1 (`niveauMin` 7 et 8, réglage inchangé). À dpr 2 et ×0,5, le HUD affiche
« niveau 8 » alors que seules les voitures sont dessinées. À ×1, la production donne 2 vélos, 145 piétons et 2 voitures, à dpr 1
comme à dpr 2. Correctif : la ligne des vivants donne ses seuils en échelle (« piétons et vélos dès ×1 »).

## Piétons et vélos dès ×0,5 (20/10, v359)

Demande de Nicolas : même seuil que les voitures (`niveauMin` 7). Sous ×1, piétons et vélos gardent la taille qu'ils ont à l'écran
à ×1 (`tailleFigee`, piéton 6,1 px, vélo 9,8 px). Sinon, ils tomberaient à 3,0 et 4,9 px. Densités inchangées ; voitures, ×1 et ×2
identiques. Stanislas à ×0,5 : 63 vélos, 878 piétons, 42 voitures (vue quatre fois plus large qu'à ×1). Planches (production,
avant v358, après v359, ×0,5, ×1 et ×2) : `docs/maquettes/vivants-labo-diorama/planche-seuil-05-dpr{1,2}.webp`. À ×1 et ×2, seuls
les pins d'opportunités (chargés de façon asynchrone) et le compteur de ms du HUD diffèrent.

## Bus et trolleybus (21/10, branche `vivants-bus`)

Portage de nancy-3d `78546f1` (rapport-vivants-v1-diagnostics § 16) : le partage des fréquences entre variantes d'une même ligne
est calculé dans le calque ; le lecteur prend `itineraires_bus_par_heure` tel quel (bus/h ÷ 3600, pas une densité).
- Réglages de la démo, inchangés : 24 px, g ≤ 1,25, échelle ×1,25, dès ×0,5 (`niveauMin` 7) ; 7 m/s sur chaussée, 8 m/s en voie
  réservée ; modèles `bus-detaille-v2` et `trolleybus-tempo1-v2`. Arrêts non marqués (décision du § 16).
- Le lecteur ne lit `bus.json` et `trolleybus.json` que si `modeles-vivants.json` contient le modèle correspondant. `vivants-v1`
  n'en a pas : aucune requête de plus, et la ligne du HUD reste la même. Crochet `?vivants-bus=0` pour les couper.
- Vérifications (Chromium 1280 × 800, dpr 1, Stanislas, Villers et gare à ×0,5, ×1 et ×2) :
  - `paquet-v2` servi en local : bus et trolleybus dessinés, aucune erreur de console. À t = 400 s : 1 bus à Villers, 2 trolleybus
    à la gare. Piétons, vélos et voitures sont identiques à ceux du paquet v1.
  - `paquet-v1` : **0 pixel d'écart** avec `main`, sur 9 cadrages sur 9 (HUD masqué, à cause de son compteur de ms).
  - `bin/rails test` : 123 verts.

## Bus et trolleybus en production (21/10, v361, `vivants-v2`)

`vivants-v2` a été publié sur R2 par nancy-3d (`publier-r2.py --publier --jeu vivants-v2`) : 13 fichiers, 15,06 Mio. Relu en ligne,
les 13 fichiers ont le sha256 du paquet et le CORS de `www.declic.site`. `vivants-v1` reste en place, avec un manifeste inchangé.
Ensuite : `VIVANTS = "vivants-v2"` (a206b21), fusion en avance rapide dans `main`, `git push heroku main:main` → **v361**.

Méthode : production avant (v360) puis après (v361) ; `?vivants=1&vivants-t=S` ; Chromium 1280 × 800, dpr 1 ; un contexte neuf
par cas. Cadrages : Stanislas, Villers et gare, à ×0,5, ×1 et ×2.
- **Pixels** (t = 40 et 400 s, HUD masqué). Pas de bus dans le cadre : 0 px d'écart (Stanislas aux deux instants, gare à
  t = 40). Avec un bus ou un trolleybus, l'écart va de 94 à 3 164 px, et il est concentré sur ce seul véhicule (planche).
  **`?vivants-bus=0` en v361 : 0 px contre v360 dans les 18 cas.** Avant la mise en ligne, le Déclic local lisant R2 rendait
  à 0 px du paquet servi en local, sur les 9 cadrages.
- **Autres familles** : sur 60 instants (0 à 1 180 s) par cas, piétons, vélos et voitures sont identiques, instant par instant,
  avec et sans bus (540 relevés sur 540). Aucune erreur de console.
- **Effectifs par image**, moyenne sur 60 instants, avec le maximum entre parenthèses :

  | cadrage | bus ×0,5 | bus ×1 | bus ×2 | trolleybus ×0,5 | ×1 | ×2 |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | Stanislas | 0,85 (4) | 0,07 (1) | 0 | 0,28 (1) | 0,05 (1) | 0 |
  | Villers | 1,20 (3) | 0,40 (2) | 0,23 (1) | 0 | 0 | 0 |
  | gare | 1,83 (5) | 0,85 (4) | 0,35 (2) | 0,27 (2) | 0,13 (2) | 0,03 (1) |

  La démo nancy-3d (§ 16, état « après ») donne la même allure, mais compte 0 à 40 % de moins. L'écart n'est pas propre aux
  bus : sur les mêmes cadrages, les voitures, dont le code n'a pas changé, sortent ×1,14 à ×1,53 au-dessus de la démo. Déclic
  compte les objets posés, y compris ceux cachés par un toit, sur une fenêtre de 1280 × 800. La démo compte les boîtes peintes,
  sur sa propre carte.
- **Occlusion** : un bus de Villers ×2 passe derrière un arbre et un toit, et il est coupé comme il faut.
- Planche : `docs/maquettes/vivants-labo-diorama/planche-bus-prod.webp` (six cadrages, avant/après, recadrage ×2).

## Vivants dès ×0,25 (21/10, branche `vivants-niveau-6`, NON déployée : rendu trop lent)

**Faisabilité : oui, sans nouvelle donnée.** Les calques sont en pixels de mosaïque du niveau 8 et couvrent toute la mosaïque ;
ils ne dépendent pas du niveau des dalles. Ce sont les mêmes trajets, vus de plus loin. Le seuil est un simple réglage du
lecteur (`niveauMin`). La capture de Nicolas (« niveau 7 · ×0,296 ») est à dpr 2 : le niveau des dalles y vaut 7 entre
×0,15 et ×0,30, et entre ×0,30 et ×0,59 à dpr 1. Le seuil est donc exprimé en échelle, comme depuis le 20/10 : **×0,25**
(`niveauMin` 6, un zoom entier comme les autres seuils). Il couvre ×0,296.

Changement (deux lignes de réglage et le HUD) : `niveauMin` passe à 6 pour les cinq familles. Sous ×0,5, voitures, bus et
trolleybus gardent leur taille de ×0,5 (`tailleFigee` 7), comme piétons et vélos gardent celle de ×1. Densités inchangées.
HUD : « visibles dès ×0,25 ».

Mesures (Déclic local lisant `vivants-v2` sur R2, Chromium 1280 × 800 sans GPU, 60 instants de 0 à 1 180 s, cinq familles) :

| cadrage | × | piétons | vélos | voitures | bus | trolleybus | JS médian dpr 1 (p90) | JS médian dpr 2 (p90) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Stanislas | 0,25 | 4 069 | 468 | 312 | 6,5 | 1,1 | 56,9 (78,6) ms | 79,9 (128,1) ms |
| Stanislas | 0,3 | 2 867 | 308 | 216 | 5,0 | 1,0 | 27,0 (46,6) ms | 28,1 (50,9) ms |
| Stanislas | 0,5 | 901 | 72 | 40 | 0,8 | 0,3 | 10,5 (14,3) ms | 10,1 (12,0) ms |
| Villers | 0,25 | 4 713 | 231 | 451 | 4,1 | 0,5 | 58,9 (90,5) ms | 69,3 (91,8) ms |
| Villers | 0,3 | 3 528 | 172 | 343 | 3,6 | 0 | 44,5 (65,2) ms | 53,9 (82,7) ms |
| Villers | 0,5 | 1 268 | 64 | 136 | 1,2 | 0 | 11,4 (27,3) ms | 11,3 (29,8) ms |
| gare | 0,25 | 3 762 | 327 | 267 | 6,3 | 0,9 | 57,8 (90,4) ms | 94,5 (137,7) ms |
| gare | 0,3 | 2 522 | 215 | 176 | 4,6 | 0,5 | 25,9 (47,1) ms | 28,2 (49,7) ms |
| gare | 0,5 | 890 | 89 | 59 | 1,8 | 0,3 | 10,9 (24,2) ms | 10,1 (25,6) ms |

- **Temps de rendu : hors fourchette.** Médiane de 26 à 59 ms à dpr 1 et de 28 à 95 ms à dpr 2, contre moins de 25 ms
  attendu. La vue couvre 2,8 fois (×0,3) à 4 fois (×0,25) la surface de ×0,5, avec 2 500 à 4 700 piétons. Profil (gare,
  horloge libre) : la peinture (découpe des toits colonne par colonne) fait 71 % du temps à ×0,25, contre 39 % à ×0,5.
  L'animation tombe à environ 13 images par seconde à ×0,25 et 19 à ×0,3 (30 visées).
- **Lisibilité** (planche `planche-seuil-025.webp`, dpr 2) : les piétons gardent leur taille de ×1. À ×0,25, ils
  paraissent hauts d'un étage et forment des traînées continues sur les rues, plutôt qu'une ville habitée.
- **×0,5 à ×2 inchangés** : 0 px d'écart avec `main` sur 18 cas (3 cadrages × 3 échelles × dpr 1 et 2), effectifs
  identiques ; `bin/rails test` vert. Contrôle à faire contre `main` en local : la production a d'autres pins d'opportunités.

Pistes, à décider (aucune n'est faite, chacune sort du périmètre « seuil et taille ») :
1. **Seuil ×0,35 ou ×0,4** : moins de surface (×2 à ×1,6 celle de ×0,5), donc plus près de 25 ms ; à mesurer, et ×0,296 ne
   serait pas couvert.
2. **Moins de piétons sous ×0,5** : on n'en peint qu'une partie, tirée par graine, ce qui touche aux effectifs validés.
   Coût presque proportionnel au nombre d'objets peints.
3. **Peinture plus légère sous ×0,5** : sans la découpe des toits (des piétons resteraient dessinés sur des toits) ou par
   paquets ; travail de fond dans le lecteur.
4. **Piétons laissés à ×0,5**, et seuls voitures, vélos, bus et trolleybus dès ×0,25 (environ 1 000 objets) : à mesurer.
