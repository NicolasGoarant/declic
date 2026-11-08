# Occupations saisonnières des places de Nancy dans le diorama

Rédigé le 08/11/2026. Construit, testé en local, **rien de déployé**. Captures : `rapports/occupations-places/`.

## Ce qui est fait

- **Mécanisme** : `config/diorama/occupations_places.yml` liste les installations (id, nom, place, début, fin, position WGS84 + altitude du sol, sprite, zooms, sources) et un catalogue de sprites (image, lumières, ancre, échelle). `DioramaOccupations` (app/models) le lit et le vérifie, puis l'envoie à la page avec les tuiles (`DioramaTuiles#pour_js[:occupations]`). Une faute de saisie vide la liste sans casser l'accueil, et le test du modèle échoue. **Ajouter une installation = ajouter un bloc YAML** (avec un sprite existant).
- **Rendu** (`app/javascript/diorama/occupations.js`, branché dans `majMeteo` comme les voiles) : le navigateur garde les installations dont la période contient le jour de Nancy (bornes incluses), et chacune est posée en `L.imageOverlay` fixe, sans boucle d'animation. Il y a deux volets, sous les vivants : l'objet, assombri le soir avec le filtre des vivants, et ses lumières, éteintes de jour et pleines la nuit (`OCCUPATIONS` dans reglages.js). Les images sont retirées hors de leur liste de zooms.
- **Occlusion** : la règle des colonnes des vivants est appliquée **une seule fois à la pose**, sur la carte de propriété du style affiché. Les houppiers et façades devant l'objet le masquent. Coût mesuré : 17 à 29 ms de calcul par installation, une fois, plus la lecture des dalles de propriété (déjà en cache si les vivants tournent).
- **Crochets** : `?occupations-jour=AAAA-MM-JJ` fait comme si l'on était ce jour-là (captures, essais) ; `?occupations=0` coupe le calque.

## Dates retenues

Cadre officiel **vérifié** sur saint-nicolas.nancy.fr (accueil et /edition-2026) : « Du 20 novembre 2026 au 3 janvier 2027 ». **La Ville n'a encore publié aucune date propre à une installation pour 2026.** Toutes les entrées portent donc `a_confirmer: true`.

| Installation | Début | Fin | Statut |
|---|---|---|---|
| Sapin, place Stanislas | **06/11/2026** | 03/01/2027 | Début **trouvé** : installé le 06/11 (ICI Grand Est, article du 06/11/2026, lu : « 20 mètres de haut », illumination le 20/11). **Retrait non trouvé** : fin officielle des Fêtes retenue. |
| Grande roue, Carrière | 20/11/2026 | 03/01/2027 | **Non trouvées pour 2026.** Les dates officielles des Fêtes ont été retenues : en 2025, le « Village de la Grande Roue et Patinoire » suivait exactement les Fêtes (programme officiel 2025 : 21/11 → 04/01). |
| Patinoire, Carrière | 20/11/2026 | 03/01/2027 | **Non trouvées pour 2026**, même raisonnement que pour la roue. |
| Grand Village (marché), Charles III | 20/11/2026 | 27/12/2026 | Début : Les Vitrines de Nancy, via Evous (01/11/2026) et nancy-focus ; non publié par la Ville. **Fin contradictoire** : 27/12 (JDS, nancy-focus, agenda des Vitrines), 28/12 (présentation des Vitrines), 26/12 (corps de l'article JDS, qui semble repris de 2025). J'ai retenu le 27/12, la date majoritaire. |

À revoir quand la Ville publiera le programme 2026 : retrait du sapin, dates propres de la roue et de la patinoire, fin du marché. Il suffit de modifier deux dates dans le YAML. Le spectacle son et lumière (vidéo-mapping de l'Hôtel de Ville) n'est pas affiché : il n'a ni date 2026 ni forme d'image fixe évidente.

**Attention** : le sapin étant installé depuis le 06/11, il s'affichera **dès le déploiement**.

## Positions choisies

Cartes publiques : contours OSM (Nominatim), altitude du sol IGN RGE ALTI (API Géoplateforme). La webcam n'a pas été utilisée. Les positions sont vérifiées à l'écran en superposant les contours projetés.

| Installation | Position (lat, lon ; sol) | Origine |
|---|---|---|
| Sapin | 48,693615 ; 6,182981 ; 200,8 m | Le sapin **relevé par le LiDAR HD du 03/12/2023** (nancy-3d `rapports/pivot-v1` § 0, L93 934214,25 ; 6848439,75), à 23 m de la statue. Le sapin de 2026 n'a pas été vérifié à cet endroit. |
| Grande roue | 48,695175 ; 6,182147 ; 198 m | « Au pied de l'Arc Héré » (programme officiel 2025 ; Destination Nancy, 27/03/2026) : sur l'axe de l'esplanade (OSM way 256714125, cap −26,8°), 16 m au nord de son bord sud. |
| Patinoire | 48,695517 ; 6,181912 ; 198 m | Carrière (programme 2025). « À l'arrière du Village de la Grande Roue » (JDS, non officiel) : centre à 58 m du bord sud, dans l'axe. |
| Marché | 48,689076 ; 6,181860 ; 204 m | Place Charles III (2025 et 2026). Partie ouest dégagée (OSM way 1008681477) ; la partie est porte un grand bâtiment. Disposition des chalets inconnue. |

## Sprites

`script/occupations_sprites.py` les rend avec la caméra et le soleil du diorama (matrice v18 de nancy-3d, vérifiée sur la `reference_de_pose` du manifeste), à 4 px d'image par pixel de mosaïque. Chaque sprite produit une image de l'objet et une image de ses lumières.

- **Sapin : réutilisé.** C'est le gabarit « conifère » de la bibliothèque d'arbres jeu-video-v2 (nancy-3d `v18-sprites-arbres.py`, sa propre fonction `cuire`, même palette), aux dimensions du sapin 2026 (20 m, rayon 4,3 m en gardant la proportion du LiDAR). S'y ajoutent une guirlande en spirale (117 ampoules, visibles seulement devant le feuillage), 60 boules colorées et une étoile. Le script exige le dépôt nancy-3d pour ce sprite.
- **Grande roue, patinoire, chalets : créés, version simplifiée et provisoire.** Ce sont des formes géométriques peintes par ordre de profondeur, avec des contours sombres :
  - **Roue** : 33 m (JDS), 18 nacelles colorées, chevalets, guichet. Le plan de la roue suit l'axe de la place : l'orientation réelle n'est **pas vérifiée**.
  - **Patinoire** : 40 m × 15 m. La longueur vient du programme 2025, la largeur des 600 m² cités par une source non officielle. Elle comprend des bandes, un chalet de location, 14 patineurs et des guirlandes sur mâts.
  - **Chalets** : 60 (programme 2025), en 5 rangées de 12, avec un étal et une guirlande sous l'avant-toit.

  L'orientation est cuite dans chaque image : une autre place demande un nouveau rendu.

Planche : `planche-sprites.jpg` (en haut de jour, en bas de nuit).

## Captures

- `sapin-z9.jpg` : Stanislas, zoom 9, heure dorée. Le sapin est à gauche de la statue.
- `carriere-z9.jpg` : Carrière, zoom 9, jour. La rangée d'arbres proche masque le bord de la patinoire et le pied de la roue.
- `charles3-z9.jpg` : Charles III, zoom 9, heure dorée.
- `nuit-stanislas-carriere-z8.jpg` : zoom 8, nuit. Guirlandes du sapin et de la roue.
- `ensemble-z7.jpg` : zoom 7, jour, les trois places.

## Limites connues

- **Patinoire peu lisible** sur la Carrière : la rangée d'arbres proche en couvre la majeure partie à ce point de vue, ce qui est exact mais discret.
- **Occlusion approchée** (règle des colonnes) : un volume situé derrière un objet mais sous son pied à l'écran le masquerait à tort. Rien de tel n'a été vu sur les trois places.
- **Pas d'ombre portée** sous les objets, contrairement aux arbres et bâtiments des dalles.
- **Le marché** n'a pas la vraie disposition des chalets, faute de plan publié.

## Tests

- `bin/rails test` : **512 verts** (505 + 7 nouveaux, `test/models/diorama_occupations_test.rb`).
- Système : nouveau `test/system/occupations_test.rb`, 4 tests verts (dates, zooms, crochet). En suite complète, 43 tests, dont 1 échec et 3 erreurs :
  - `fiches_test.rb:65` (connu) et `ambiances_test.rb:58` (intermittent connu) ;
  - délais dépassés (`ScriptTimeoutError`) sur `occupations_test.rb:39` et `geoloc_auto_test.rb:99`. Les deux passent deux fois de suite en isolé : charge de la machine pendant la suite (serveur de développement et navigateur de capture ouverts en parallèle).
