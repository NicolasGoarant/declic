# Audit du niveau de détail du diorama aux zooms 7, 8 et 9 : bâtiments, végétation, rues et mobilier

Rédigé le 07/11/2026. Audit seul : aucune ligne de code modifiée, ni dans Déclic ni dans nancy-3d.

**Ce qui a été lu**
- Déclic (`main`, `b75e19a`) : `app/javascript/diorama/*`, `diorama_controller.js`, `app/models/diorama_tuiles.rb`.
- nancy-3d (`main`, `0c8f53d`) :
  - `apercu-oblique.py` ;
  - `rapports/jeu-video-v2/scripts/v01`, `v02`, `v05`, `v06`, `v07`, `v18`, `v19` ;
  - `rapports/facades-v1/scripts/f0*` ;
  - `rapports/niveau9/` ;
  - `rapports/declic-couches-v1/scripts/c0*` ;
  - `extraction-stanislas-v3.py`, `osm_local.py`, `NOTES.md`.
- Les manifestes R2 ont été interrogés en direct.

**Captures, hors dépôt.** Elles sont dans `/tmp/claude-1000/-home-goarant-Documents-declic/1d992c73-4752-40f1-8fc9-5876a26f1e82/scratchpad/captures/` :
- `planche-{stanislas,pepiniere,saint-epvre,residentiel,marechaux,meurthe}.png` : le même terrain (une dalle n8) vu à z7, z8 et z9. La surcouche `lotissement2` est appliquée.
- `masque-arbres-sur-jv2-{70-35,66-45,69-37}.png` : le masque d'automne publié, en magenta, posé sur le rendu jv2.

Elles ont été assemblées par script à partir des dalles publiées, sans les vivants ni l'ambiance. Les scripts sont dans le même dossier.

---

## 0. Trois constats qui cadrent tout le reste

1. **Le décor est cuit dans des images.**
   - Bâtiments, arbres, sol, rues et mobilier sont peints une fois pour toutes par le rasteriseur Python de nancy-3d (style `jeu-video-v2`, « jv2 »). Ils sont publiés en dalles WebP de 256 px sur R2.
   - Déclic ne dessine aucun de ces objets. Il pose par-dessus :
     - un étalonnage WebGL **par dalle**, calculé une fois à la création de la dalle (`ambiance.js:584`, `:683`) : saisons, pluie et neige, nuit, fenêtres allumées ;
     - les lumières de nuit (`lampadaires.js`) ;
     - des calques animés (vivants, bateaux, trains, voiles, précipitations).

   **Conséquence** : tout enrichissement « dans la dalle » passe par un **recalcul nancy-3d**. Tout enrichissement « dans Déclic » passe par une **couche par dalle** calculée côté navigateur.
2. **Il n'existe aucune logique de niveau de détail entre z7, z8 et z9.**
   - **z7** est une réduction 2 × 2 de z8, en RVBA prémultiplié (`v07-calcul.py:429-477`). Il n'a aucun rendu propre.
   - **z9** est un vrai rendu 3D à deux fois la résolution : 4,525 px/m contre 2,263 (`rapports/niveau9/scripts/n9-port.py`, `N9_K = 2`). Mais il a **la même géométrie et les mêmes règles en mètres** que z8.
   - z9 est donc plus net, il ne montre rien de plus. Les planches le confirment : mêmes cheminées, mêmes parasols, mêmes arbres. Seuls les contours s'affinent.
   - Le seul réglage pensé pour la résolution va dans le sens contraire : le pas des rangs de tuiles est choisi pour rester **≥ 2 px au niveau 8** (`v01-batiments.py:209-210`, `:1427`). Il n'est jamais affiné au niveau 9.
3. **Tout recalcul est cher et n'a plus de machine dédiée.**
   - Coûts mesurés :
     - niveau 8 : environ 4 h pour 9 104 dalles à 3 travailleurs (`jeu-video-v2/rapport.md:362`), environ 10 h avec les réglages actuels (`docs/plan-reconstruction-2026-10-28.md:80`) ;
     - niveau 9 : 36 416 dalles, 20 à 27 h au devis, plus de 50 h selon le plan de reconstruction ;
     - retouches à rejouer ensuite (rails, abris, lucarnes, deux-pans) : 65 à 75 h en tout (plan, l.80-83).
   - **Le serveur `nancy-3d-calc` est supprimé depuis le 06/11** (snapshot 452912306).
   - Les dalles sont `immutable` : toute dalle refaite doit être publiée sous un **nouveau nom de jeu**, en surcouche, comme `lotissement2`.
   - Les façades du 30/10 ne sont pas recalculables à l'identique sans l'archive `nancy-3d-facades`.

   Dans les tableaux ci-dessous, « recalcul » signifie donc toujours : restaurer le snapshot ou calculer en local, puis publier une surcouche.

**Inventaire publié (manifeste R2 de `jeu-video-v2`)**
- Dalles par niveau : z7 2 354, z8 9 104, z9 35 754. La surcouche `lotissement2` en porte 524, 865 et 1 454.
- Les cartes annexes (propriété, masque du bâti, masque des arbres) **s'arrêtent au niveau 8**. À z9, Déclic les agrandit au plus proche voisin (`couches.js:9-19`).

---

## 1. Bâtiments

### 1.1 État actuel

**Génération**
- La géométrie est procédurale et vectorielle (`v01-batiments.py`). Elle part des **corps BD TOPO** segmentés sur le **LiDAR HD**.
- L'emprise est simplifiée à 0,45 m et remise d'équerre.
- La famille de toit est reconnue par le LiDAR : terrasse, deux-pans, croupe, mansarde. Le toit est ensuite calé par moindres carrés sur le modèle de surface.
- **OSM ne sert pas à la géométrie.** Il ne sert qu'aux monuments (`heritage`), aux vitrines et aux terrasses.

**Attributs exploités**
- Hauteurs : altitudes de gouttière et de faîtage, `hauteur`, azimut et pente du faîtage, couleur du toit mesurée sur l'orthophoto.
- Façades (`facades-v1/scripts/f02-facades.py`) : `materiaux_des_murs`, à défaut BDNB `mat_mur_txt` ; BDNB `annee_construction` ; `usage_1` ; `nature` ; `nombre_d_etages`.
- Matériau du toit : décidé par l'« orangité » de l'orthophoto et l'année BDNB (avant 1914 → ardoise). Les 368 édifices remarquables sont forcés en ardoise.

**Détails déjà présents à z8 et z9**

| Détail | Où |
| --- | --- |
| Fenêtres en grille travée × étage, trumeaux, encadrements | f02 `peindre`, l.384-499 |
| Volets colorés, balcons, corniche, soubassement, cordon ; 5 familles de façade (volets, balcons, bandeaux, arcades, sobre) | f02 l.54-66, 289-302 |
| Portes sur rue, portes de garage | f02 `mur` l.363-379 |
| Vitrines et stores (SIRENE et OSM) | f02 l.350-362 |
| Terrasses : 939 terrasses, 3 146 parasols, tables et chaises | `v02-pilote.py:822-965` |
| Lucarnes 3D (règle « une tous les 4,5 m », mansardes tous les 3,2 m) | v01 l.1212-1284 |
| Cheminées, édicules d'escalier, extracteurs sur toits plats | v01 l.1088-1171 |
| Rangs de tuiles (0,95 m) et d'ardoises (0,70 m) | v01 l.1550-1564 |

**Côté Déclic**
- La nuit allume les fenêtres peintes de jv2 (`ambiance.js`, uniform `fenetresPeintes`).
- La neige blanchit les toits par le masque du bâti.
- Les façades sont déduites par le shader : un pixel bâti juste au-dessus du sol est compté comme façade.

**Par niveau**
- **z7** : la grille des fenêtres se brouille en hachures, les cheminées deviennent des points (planche `residentiel`).
- **z8** : tout est lisible au pixel près.
- **z9** : les mêmes éléments, nets. On voit que les rangs de tuiles ont 4 px de pas là où ils pourraient en avoir 2.

**Défauts ouverts qui pèsent sur le détail**
- 164 hangars flottants ;
- 681 bâtiments écrasés ;
- 111 cours sous toit ;
- au moins 4 groupes de maisons hors BD TOPO ;
- les remarquables, Saint-Epvre en tête, ne rentrent pas dans les familles de toit ;
- 46 dalles z9 sans l'effet deux-pans.

### 1.2 Données disponibles et inutilisées

- **BD TOPO** (présentes dans `batiments.geojson` et `corps-batiments.geojson`, jamais lues par v01, v02 ou f02) :
  - `materiaux_de_la_toiture` : le toit vient de l'orthophoto seule ;
  - `construction_legere`, `usage_2`, `nombre_de_logements`, `date_d_apparition`, `identifiants_rnb`.
- **BDNB** : `usage_niveau_1_txt` est extrait (f01 l.117) mais jamais utilisé.
- **OSM** : `building:material`, `roof:shape`, `roof:colour`, `building:levels` et `building:colour` ne sont **ni extraits ni lus**. L'extraction ne télécharge aucun bâtiment OSM.

### 1.3 Propositions sans nouvel asset, par ordre de priorité

| # | Proposition | Où | Complexité |
| --- | --- | --- | --- |
| B1 | **Cartes annexes natives au niveau 9** (propriété, masque du bâti), dérivées de la mosaïque n9 qui existe déjà. Aujourd'hui, l'ambiance de z9 lit des cartes n8 agrandies ×2 : façades déduites, neige sur les toits, fenêtres de nuit et ombres de contact ont des bords en escalier de 2 px. | nancy-3d (dérivation, pas de rendu) puis publication ; Déclic : lire le niveau 9 quand il existe (`NIVEAU_ANNEXES`) | moyenne |
| B2 | **Motifs affinés au seul niveau 9** : demi-pas des rangs de tuiles et d'ardoises, meneaux et petits-bois, garde-corps de balcon en trait, joints de corniche. Les règles en mètres existent, seul le seuil « ≥ 2 px au niveau 8 » est à rendre dépendant de K. | `v01-batiments.py`, `f02-facades.py`, rendu n9 seul | moyenne (règles) / complexe (recalcul n9 de 20 à 50 h) |
| B3 | **`construction_legere`** pour rendre abris, appentis et hangars plus bas et plus clairs (bardage, tôle). Recoupe peut-être une partie des 164 hangars flottants et des annexes trop hautes. | v01, `famille_et_hauteurs` | simple (règle) / complexe (recalcul n8 + n9) |
| B4 | **`materiaux_de_la_toiture` en arbitre** quand l'orthophoto hésite (zinc, ardoise, tuile mécanique, bac acier), plutôt que le tirage au hasard zinc/ardoise des mansardes. | v01 `materiau_toit` l.710-731 | simple (règle) / complexe (recalcul) |
| B5 | **Usage** (`usage_1`, `usage_2`, BDNB `usage_niveau_1_txt`) : rez-de-chaussée vitré seulement pour le commerce, portes d'entrepôt pour l'industriel, rythme plus large pour l'équipement public. La famille « sobre » couvrirait alors moins de bâtiments. | f02 `caracteres` | moyenne |
| B6 | **Liseré de façade à la nuit, côté Déclic** : allumer l'encadrement des portes des vitrines (déjà peintes) d'une lueur propre, comme les fenêtres. Aucun recalcul, seulement le shader par dalle. | `ambiance.js`, `reglages.js` | simple |
| B7 | **Corriger les défauts ouverts** (bâtiments écrasés, hangars flottants, cours sous toit) avant d'ajouter du détail : à z9, un toit faux se voit davantage qu'une fenêtre manquante. | chantiers ouverts de nancy-3d (`NOTES.md`) | complexe |

### 1.4 Propositions qui demandent des assets absents

- **Façades caractéristiques de Nancy** : Art nouveau, place Stanislas (grilles dorées de Lamour, balustrades et pots à feu), arcs Héré. Il faudrait des modèles ou gabarits de façade dessinés, monument par monument.
- **Toits singuliers** : coupoles, clochers, flèches (Saint-Epvre, cathédrale, basilique Saint-Sébastien) en modèles 3D. Les familles paramétriques ne savent pas les dire.
- **Textures de matériaux** (pierre de taille, brique, enduit vieilli) : le moteur n'a ni textures ni fichiers de matériaux, seulement des couleurs plates et des motifs tracés.
- **Enseignes, auvents à motifs, jardinières aux fenêtres** : sprites à dessiner.

---

## 2. Végétation

### 2.1 État actuel

**Arbres**
- 663 345 sujets, issus de deux sources :
  - le **LiDAR HD**, avec hauteur et rayon mesurés ;
  - **OSM** `natural=tree` et `tree_row` (rangées échantillonnées tous les 8 m).
- Ils sont fusionnés à 3 m (`v06-arbres.py:340-427`) et recalés à 4 m de la chaussée et de l'eau. Le contrôle donne 0 arbre sur la chaussée, dans l'eau ou dans le bâti.
- **8 silhouettes procédurales** : rond, ovale, conique, colonne, pleureur, platane, fruitier, arbuste. Elles sont choisies selon le contexte (forêt, parc, distance à l'eau ou à un axe) et selon `genus` et `leaf_type` quand OSM les donne.
- Un **mode sprites de 15 arbres** existe (`v18-sprites-arbres.py` : 10 feuillus, 3 conifères, 2 colonnes, plus une variante n9), mais il est **éteint par défaut** (`V2_ARBRES_SPRITES`).

**Sol végétal**
- Polygones OSM : `park`, `garden`, `pitch`, `grass`, `forest`, `cemetery`, `village_green`, `wood`. Ils sont tous peints de la même teinte plate (`apercu-oblique.py:8131`), puis repeints en deux tons « herbe / minéral » par jv2.
- **Seuls les `way` sont extraits** : les multipolygones (relations) manquent, d'où une forêt de Haye incomplète.
- Il n'y a ni haie, ni prairie, ni champ, ni verger, ni vigne, ni jardin familial.

**Données Géonancy** : les essences (GENRE, ESPECE, HAUTEUR, HOUPPIER) **ne sont pas portées** dans jv2. L'option est bloquée par une assertion, « pas encore implémentée ».

**Par niveau**
- **z7** : les houppiers fondent en masses.
- **z8** : les arbres sont distincts, ombrés, avec leur ombre portée.
- **z9** : mêmes arbres et mêmes gabarits. Les amas sont seulement plus fins, jusqu'à 0,66 m, et le masque du feuillage est calculé nativement (27,7 % des pixels de feuillage diffèrent d'un simple agrandissement). Planche `pepiniere` : le contenu est identique de z8 à z9.

**Saisons et météo** (Déclic, `reglages.js:348-358`)
- L'automne (octobre et novembre) teinte les pixels du `masque-arbres`, une cellule de Voronoï par houppier, du jaune au roux.
- L'hiver (décembre à février) est un étalonnage global. **Il n'y a pas d'arbres nus** : la classe feuillage est seulement protégée.
- La neige vient de la météo réelle (`meteo.js`, codes WMO). Elle blanchit toits et sol mais **épargne les houppiers** (`ambiance.js:242`).
- La pluie assombrit le sol. Aucun effet sur la végétation elle-même.

### 2.2 Défaut constaté pendant l'audit : le masque d'automne ne correspond pas aux arbres de jv2

**Le défaut**
- `masque-arbres` est calculé sur le rendu **toits-v1** : volume ∩ jaune-vert (`declic-couches-v1/scripts/c01-masque-arbres.py`).
- Or jv2 a **retiré** les couronnes v1 et posé ses propres arbres, plus gros.

**La mesure** : masque publié contre pixels verts de la dalle jv2, au niveau 8.

| dalle | part du vert jv2 couverte par le masque | part du masque qui tombe sur du vert jv2 |
| --- | --- | --- |
| 8/70/35 (Pépinière) | 45 % | 99 % |
| 8/66/45 (résidentiel) | 43 % | 89 % |
| 8/69/37 (Stanislas) | 68 % | 62 % |

**Ce qu'on voit** (`masque-arbres-sur-jv2-69-37.png`)
- Le masque déborde sur le pavé de la place et sur les ombres portées.
- Il laisse des houppiers entiers hors du masque.

**L'effet** : en ce moment même (automne actif jusqu'à fin novembre), une partie des arbres reste verte, et des taches de sol peuvent virer au roux. C'est la priorité V1 ci-dessous.

### 2.3 Données disponibles et inutilisées

**Dans le cache OSM des arbres**
- `leaf_type` ×1 967 : lu.
- `leaf_cycle` ×663, `species` ×414, `denotation` ×92 : **jamais lus**.
- `height` ×97 et `genus` ×84 : lus.

**Géonancy** : GENRE, ESPECE, HAUTEUR et HOUPPIER pour les arbres d'alignement. La v1 les exploitait (`apercu-oblique.py:3718-3727`).

**OSM jamais demandé**
- `barrier=hedge` ;
- `natural=scrub` ;
- `landuse=meadow`, `farmland`, `orchard`, `vineyard`, `allotments` ;
- `natural=grassland` ;
- les relations multipolygones.

**Lu mais rendu pareil** : `cemetery`, `pitch`, `grass` et `wood` ont la même teinte.

### 2.4 Propositions sans nouvel asset, par ordre de priorité

| # | Proposition | Où | Complexité |
| --- | --- | --- | --- |
| V1 | **Refaire `masque-arbres` sur jv2** et le publier sous un nouveau nom. Deux chemins : écrit par `v06` au moment de poser les arbres (le mode « natif » de `v19-automne-simule.py` le prévoit, avec la précocité dans l'octet), ou recalculé sur la mosaïque jv2 avec `propriete-jv2` (cartes déjà publiées pour l'ambiance). Ajouter le niveau 9. Aucun recalcul de dalle. | nancy-3d `c01` ou `v19`, puis `DioramaTuiles::ARBRES` | simple à moyenne |
| V2 | **Précocité d'automne par essence** (`species`, `genus`, `leaf_cycle`, Géonancy ESPECE) au lieu d'un tirage au hasard : les érables tournent tôt et rouge, les platanes tard et brun, les conifères ne tournent pas. Dans l'octet du masque, lu par le shader existant. | `v06` (tirage l.222), `ambiance.js` | moyenne |
| V3 | **Hiver sans feuilles, approché côté Déclic** : sur le masque (V1), désaturer et brunir les feuillus (`leaf_type`/`leaf_cycle` dans le masque), éclaircir le cœur des houppiers pour suggérer la ramure, garder les conifères verts. Puis **neige sur les houppiers** les jours de neige, aujourd'hui exclus. Ce n'est qu'une approximation : de vrais arbres nus demandent des sprites (§ 2.5). | `ambiance.js`, `reglages.js` | moyenne |
| V4 | **Distinguer les sols végétaux** déjà lus : terrains de sport (`pitch`) avec leurs lignes blanches à z9, cimetières plus sombres avec allées, pelouses de parc plus claires que les friches. | `apercu-oblique.py` puis v02 (recalcul) | moyenne (règles) / complexe (recalcul) |
| V5 | **Relations multipolygones OSM** (forêts, grands parcs) et nouveaux `landuse` (prairie, champ, verger, jardins familiaux). Les champs ne viennent aujourd'hui que de la couleur de l'orthophoto. | `extraction-stanislas-v3.py`, `osm_local.py` | moyenne (extraction) / complexe (recalcul) |
| V6 | **Haies** (`barrier=hedge`) en ruban volumique vert, avec la logique des arbustes peints. | v06 ou `apercu-oblique.py` | moyenne / recalcul |
| V7 | **Allumer `V2_ARBRES_SPRITES`** (15 sprites déjà dessinés, variante n9 comprise) pour varier les silhouettes à z9, et y brancher `species` et `leaf_type`. À juger sur planche avant tout recalcul : le mode est éteint, il y a peut-être une raison. | v06, v18 | moyenne / recalcul |
| V8 | **Réconcilier les cimes écrasées** : l'étirement vertical est plafonné à ×1,12 ou ×1,35, donc les grands arbres sont trop bas. | v06 | simple (règle) / recalcul |

### 2.5 Propositions qui demandent des assets absents

- **Arbres nus d'hiver** : sprites de ramure par silhouette. C'est la seule façon d'avoir un vrai hiver.
- **Essences reconnaissables** : marronnier en fleurs, tilleul, platane à écorce claire, cèdre, saule. Les 15 sprites de v18 sont génériques.
- **Massifs fleuris saisonniers** (Géonancy `espaces_verts`, jardin éphémère de la place Stanislas) : motifs de fleurs.
- **Mobilier de parc** : kiosque de la Pépinière, serres, aires de jeux (50 `leisure=playground` à Nancy).

---

## 3. Rues et mobilier urbain

### 3.1 État actuel

**La base `toits-v1` est riche**
- Rubans OSM `highway` : largeur `width`, sinon largeur par type plus `lanes` × 3 m.
- Classes de surface : chaussée, trottoir (`footway=sidewalk`, surélevé de 0,15 m avec bordure, ou généré à partir des tags `sidewalk*`), bande cyclable, couloir bus.
- Textures : pavés `sett` (pas de 1,6 m), calepinage des places piétonnes.
- Marquages : **passages piétons à bandes** pour chaque `footway=crossing`, **trait d'axe** pointillé sur les voies secondaires et tertiaires.
- Sources : `apercu-oblique.py:4347-4746`.

**jv2 efface presque tout**
- `v02-pilote.py:1216-1414` **repeint tout le sol** (codes 1 et 3) en deux tons plats : minéral ou herbe.
- Pavés, trottoirs, bordures, passages et traits d'axe ne survivent qu'en faible modulation de clarté. La médiane de 5 px (l.1411) gomme justement les joints clairs.
- Planches `marechaux` et `residentiel` : chaussées et trottoirs forment **un seul aplat lavande**, sans marquage ni bordure visible. La place Stanislas est un aplat rose.

**Mobilier peint dans les dalles**
- **Lanternes Géonancy** : mât et tête, hauteur déduite de `TYPELANT`. Ce sont les tiges sombres de la place Stanislas.
- **Voitures stationnées** : selon les tags `parking:*`, avec un repli sur les rues résidentielles.
- **Passants** sur les esplanades.
- **Terrasses à parasols**.
- La statue de Stanislas, comme volume.
- **Absents** : bancs, abribus, bornes, corbeilles, fontaines, feux, signalisation, arbres en fosse (hors arbres LiDAR et OSM).

**Côté Déclic**
- La nuit pose des lampadaires **procéduraux** tous les 18 à 25 m le long de la BD TOPO (`lampadaires-bdtopo.json`). Les lanternes Géonancy relevées (`lumieres-nuit`) ne sont pas publiées.
- Les flaques de lumière des places viennent de `nuit-chaude-v1`.

**Par niveau**
- **z7** : les rues ne sont plus que des couloirs lavande.
- **z8** : parasols et voitures garées sont lisibles.
- **z9** : idem, plus nets.
- **Le niveau 9 n'a pas les rails de l'option A** (`NOTES.md` de nancy-3d).

**Défauts ouverts**
- Voirie peinte sur l'eau.
- Aplat et ombres lavande à la place des abris de quai effacés (z8).
- Reconstruction E8 non éprouvée sur les routes (+174 tronçons) et les voies.

### 3.2 Données disponibles et inutilisées

**Tags de voirie présents dans le cache, jamais lus** (échantillon de 19 tuiles locales, 7 347 objets)

| tag | nombre |
| --- | --- |
| `sidewalk*` | 1 011 |
| `cycleway:*` | 599 |
| `oneway` | 1 095 |
| `lit` | 792 |
| `lane_markings` | 102 |
| `turn:lanes` | 70 |
| `traffic_calming` | 88 |
| `crossing:markings=zebra` | 51 |
| `layer` | 90 |

**Nœuds OSM jamais extraits.** L'extraction ne prend que les `way`. Dans l'extrait `lorraine-latest.osm.pbf` du lot A, boîte 6,11–6,34 E / 48,63–48,78 N :

| objet | nombre |
| --- | --- |
| `highway=street_lamp` | 16 100 |
| `highway=crossing` | 8 499, dont 7 494 en `zebra` |
| `amenity=bench` | 2 715 |
| `traffic_signals` | 1 535 |
| `waste_basket` | 1 489 |
| `bicycle_parking` | 1 392 |
| `bus_stop` | 1 003, dont 46 avec abri |
| `barrier=bollard` | 652 |
| `artwork` | 127 |
| `street_cabinet` | 119 |
| `drinking_water` | 68 |
| `leisure=playground` | 50 |
| `fountain` | 34 |

**Géonancy `lanternes.geojson`** : 7 924 points. Seul `TYPELANT` est lu ; `MATIERE` et `RAL` (couleur du mât) dorment.

### 3.3 Propositions sans nouvel asset, par ordre de priorité

| # | Proposition | Où | Complexité |
| --- | --- | --- | --- |
| R1 | **Lampadaires de nuit sur les vraies positions OSM** (16 100 `street_lamp`), complétés par les lanternes Géonancy, au lieu du semis procédural de la BD TOPO. Même format `nancy-3d/lumieres-nuit`, que `lampadaires.js` lit déjà. Pas de recalcul de dalle. | nancy-3d (export de points au niveau 8), R2, `DioramaTuiles::LAMPADAIRES` | simple |
| R2 | **Rendre au sol de jv2 ses marquages et bordures** : passages piétons, traits d'axe, bordures de trottoir, joints de pavés à z9. Deux voies : (a) dans l'habillage v02, en laissant passer ces classes de la base au lieu de les aplatir (recalcul n8 et n9) ; (b) **côté Déclic**, une passe par dalle qui trace les passages (8 499 nœuds `crossing`) et les bordures depuis le vecteur, masquée par la carte de propriété (sol seulement), comme l'ambiance. La voie (b) évite tout recalcul et se règle en direct. | v02 l.1216-1414, ou nouveau module Déclic appelé dans `createTile` | moyenne |
| R3 | **Mobilier procédural à partir des nœuds OSM**, sur le modèle des lanternes et des parasols (primitives : boîte, cylindre, tête) : bancs (2 715), bornes (652), corbeilles (1 489), arceaux vélo (1 392), feux (1 535), poteaux d'arrêt de bus (1 003). Lisible à z9 seulement (un banc fait 2 m, soit 9 px à z9) ; à réserver au niveau 9 pour ne pas brouiller z8. | `osm_local.py` (extraction des nœuds), `preparer_mobilier`/`peindre_mobilier` (`apercu-oblique.py:4773`, `:6960`) | moyenne (règles) / complexe (recalcul n9) |
| R4 | **Bandes et pistes cyclables colorées** (`cycleway:*`, 599 tronçons) et couloirs bus, aujourd'hui fondus dans l'aplat. Même choix de voie que R2. | v02 ou passe Déclic | moyenne |
| R5 | **Feux tricolores la nuit, côté Déclic** : un point rouge, orange ou vert sur les 1 535 `traffic_signals`, dans `dessinerFeux`, qui trace déjà les feux des mâts en 2D. | `lampadaires.js` | simple |
| R6 | **Couleur des mâts** (Géonancy `RAL`) et matière, pour les lanternes déjà peintes. Gain visible seulement à z9. | `apercu-oblique.py` `TYPELANT` l.4173 | simple (règle) / recalcul |
| R7 | **Flèches au sol** (`turn:lanes`, `oneway`) et ralentisseurs (`traffic_calming`). Faible valeur pour une maquette ; z9 seulement. | passe Déclic ou v02 | complexe pour peu de gain : à écarter |
| R8 | **Corriger la voirie peinte sur l'eau et ajouter les rails de l'option A au niveau 9** avant tout ajout au sol. | chantiers ouverts de nancy-3d | moyenne |

### 3.4 Propositions qui demandent des assets absents

- **Abribus** (46 `shelter=yes` ; le reste des arrêts n'est pas renseigné) : modèle 3D de l'abri du réseau Stan.
- **Kiosques à journaux, colonnes Morris, sanisettes, stations de vélos en libre-service** : modèles.
- **Fontaines et statues** : Neptune et Amphitrite (Stanislas), fontaines des places, 127 `artwork`.
- **Signalisation verticale** (panneaux, plaques de rue), **potelets nancéiens**, **grilles d'arbres**.
- **Marché couvert, étals** (voir l'audit des animations du 03/11 : marché absent).

---

## 4. Effet sur les performances

**Ce qui ne bouge pas.** Le plafond des animations n'est pas touché par un enrichissement statique, et les garde-fous (`saveData`, `prefers-reduced-motion`, onglet caché) ne s'appliquent qu'aux calques animés. Plafonds actuels : 30 images/s au repos et 12 pendant un geste pour vivants et bateaux (`vivants.js:550`, `mobiles.js:164`), 15 pour les voiles (`voiles.js:12`).

**Détail cuit dans les dalles (B2-B5, V4-V7, R3, R6) : coût de rendu nul.**
- Une dalle reste une image de 256 px, quel que soit ce qu'elle montre.
- Le nombre de dalles visibles ne dépend pas du zoom : environ 15 à 25 pour une fenêtre de 1 366 × 768.
- Au zoom le plus large, z7, il n'y a pas « plus d'objets » à dessiner : il y a la même vingtaine d'images, dont chacune couvre quatre fois plus de terrain.
- Le seul coût est le **poids**. Mesuré sur les six sites : z8 = 8 à 30 Ko par dalle ; z9 = 18 à 100 Ko pour les 4 dalles couvrant le même terrain, soit 5 à 25 Ko chacune. Un détail plus fin (joints, mobilier) augmentera l'entropie du WebP de z9.
- **Estimation non mesurée** : +10 à +30 % d'octets à z9, sans effet sur les images par seconde. Le chargement est déjà dominé par les photos de fiches (5,1 Mo, `perf-carte-2026-11-02.md` § 4).

**Détail calculé côté Déclic (B1, B6, V1-V3, R2b, R4b) : coût par dalle, pas par image.**
- L'ambiance est déjà une passe WebGL **à la création de chaque dalle**. Y ajouter des règles (essence d'automne, hiver, liseré de vitrines) coûte quelques instructions de shader par pixel, une fois.
- Une passe qui **trace du vecteur** (R2b : passages, bordures) coûte en proportion du nombre d'objets dans la dalle. **C'est là que z7 pèse** : une dalle z7 couvre 4 dalles z8, donc environ 4 fois plus de passages à tracer, pour un résultat illisible (un passage fait 2 à 3 px à z7).
- Recommandation : **ne pas tracer de détail vectoriel sous z8**, et le mettre en cache par dalle comme le fait l'ambiance.
- Le précédent à ne pas reproduire : une **nouvelle couche Leaflet de toiles**. L'audit du 02/11 mesure que la couche de tuiles-toiles coûte déjà de 5,6 à 7,0 images/s (bridage ×4). Mieux vaut peindre dans la toile existante de l'ambiance.
- Ce détail statique **n'a pas à être coupé** par `prefers-reduced-motion` : rien ne bouge. `saveData` peut en revanche sauter les cartes annexes du niveau 9 (B1), qui ajoutent des requêtes.

**Calques animés : à éviter pour le détail.** Mettre du mobilier ou des arbres dans un calque animé (sur le modèle de `vivants.js`) ferait payer chaque objet **à chaque image**. Ce sont précisément ces boucles qui coûtent le plus aujourd'hui (32 à 34 % du temps CPU, audit du 02/11). Le détail statique doit rester soit dans la dalle, soit dans la passe par dalle.

**Coût de production.** C'est le vrai coût, et il n'est pas côté navigateur : chaque proposition « recalcul » mobilise de 4 à 10 h (n8) ou de 20 à 50 h (n9) de machine, sans serveur aujourd'hui, et une publication en surcouche. Il faut **grouper** les changements dans un même recalcul, et ne recalculer que n9 pour ce qui n'est lisible qu'à z9.

---

## 5. Synthèse et ordre suggéré

**Sans aucun recalcul de dalle (Déclic, plus des dérivations légères dans nancy-3d)**
1. **V1** masque d'automne refait sur jv2 : simple à moyenne. Défaut visible dès maintenant.
2. **R1** lampadaires sur les positions OSM et Géonancy : simple.
3. **R5** feux tricolores de nuit : simple.
4. **B6** liseré des vitrines la nuit : simple.
5. **B1** cartes annexes natives au niveau 9 : moyenne.
6. **V2** et **V3** automne par essence, hiver approché, neige sur les houppiers : moyenne. V2 et V3 dépendent de V1.
7. **R2b** et **R4b** passages piétons, bordures et pistes cyclables tracés par dalle, à z8 et z9 : moyenne.

**Avec recalcul, à grouper en un seul passage n8 + n9, après les correctifs ouverts (B7, R8)**
- n8 et n9 : B3, B4, B5, V4, V5, V6, V8.
- n9 seul : B2, R3, R6, V7.

**Avec nouveaux assets, à décider à part**
- Façades et monuments nancéiens, textures de matériaux.
- Arbres nus et essences reconnaissables, massifs fleuris, mobilier de parc.
- Abribus, kiosques, fontaines, statues, signalisation.

**Ce que cet audit n'a pas vérifié**
- Le rendu en ambiance réelle (nuit, automne) dans le navigateur : les captures sont des dalles brutes, sans les vivants ni l'étalonnage.
- Le surcoût réel en octets d'un détail plus fin à z9 : c'est une estimation.
- La raison de l'extinction de `V2_ARBRES_SPRITES`.
- Si les volumes de mobilier de la base (voitures, lanternes) passent tous dans jv2 : vu sur planche, pas mesuré au pixel.
- Les décomptes de tags de voirie : un échantillon de 19 tuiles locales sur 274.
