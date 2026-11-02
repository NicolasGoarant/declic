# Audit de performance de la carte d'accueil — www.declic.site, 02/11/2026

Audit seul : aucun code modifié. Mesures faites en production sur l'accueil (`/`), Chromium piloté par Playwright, fenêtre 1366 × 768, GPU réel (Intel UHD 620, via ANGLE).

## Méthode et limites
- **Poste « standard »** : le poste de test est plus puissant qu'un PC de bureau courant, donc les mesures sont données **sans bridage** et avec le processeur **bridé ×4** (CDP `Emulation.setCPUThrottlingRate`), qui approche un PC de bureau d'entrée de gamme. Les chiffres bridés sont des ordres de grandeur, pas une mesure sur machine réelle.
- **Séquence** : 5 crans de molette en zoom avant, glissement de 40 pas (~480 px), 5 crans en zoom arrière, rejeu du zoom avant. FPS lus par `requestAnimationFrame`, tâches longues par `PerformanceObserver('longtask')`, CPU par `Profiler` CDP (le profileur ralentit lui-même la page).
- **Bruit** : une seule exécution par condition. Deux passes identiques de la mesure « de base » ont donné 5,6 et 8,6 FPS au repos (5,7 et 7,9 au déplacement) : **ne retenir que les écarts d'un facteur ~2**.
- **Masquage de couches** (`display:none`) : retire le coût de peinture et de mise en page, **pas** le JavaScript qui continue de dessiner. Il sous-estime donc le poids des canvas animés.

## Résultats chiffrés

| Condition | Repos (3-5 s, sans geste) | Pendant le glissement |
|---|---|---|
| Sans bridage | 43 FPS, 3 tâches longues = 459 ms | **20 FPS**, 48 tâches longues = 3,5 s, images > 50 ms : 37 sur 155 |
| Zoom arrière / rejeu zoom avant (sans bridage) | | 19 et 20 FPS, 19 et 18 tâches longues (1,2 s chacun) |
| Bridage ×4 | **5 à 9 FPS** (images de 83 à 133 ms) | **4 à 8 FPS**, tâches longues de 13 à 26 s cumulées |

Le premier zoom avant sans bridage (42 FPS) est flatté : tuiles déjà prêtes, rien d'autre ne bouge. La lenteur ressentie correspond aux gestes suivants (glissement, zoom arrière).

**À retenir** : la page est déjà à 5-9 FPS bridée **sans toucher à la carte**. Un coût permanent, hors interaction, est donc la cause principale.

## Diagnostic classé par impact probable

### 1. Boucles de dessin canvas permanentes `vivants` et `mobiles` — impact majeur
- Deux canvas de 970 × 696 (taille de la carte) repeints jusqu'à 30 fois par seconde en continu (`INTERVALLE_MS = 1000/30 - 2`, `vivants.js:42`, `mobiles.js:58`), **y compris au repos et pendant le glissement/zoom**, car le temps avance (piétons, vélos, voitures, bus, bateaux, trains).
- Profil CPU bridé ×4, 5 s au repos : `boucle` (vivants) = **32 % du temps total**, dont `peindre` 21 % et `poserCalque` 9 % ; `vivants.js` seul 15 % de temps propre ; ajouter les appels natifs `save`/`restore` 13 %, `drawImage` 4 %, `getImageData` 3 %.
- Profil pendant déplacement + zoom : `boucle` **34 %**, `peindre` 17 %, `poserCalque` 14 %, `vivants.js` 24 % de temps propre. Les gestionnaires de carte (`majVolet`) pèsent < 1 % : **ce n'est pas la logique de zoom qui coûte**.
- Historique : ces boucles datent du 20-27/10 (« Vivants sur la page d'accueil », trains par défaut le 27/10), **avant** les 85 fiches de la veille.
- Pistes : suspendre ou passer à 10-15 FPS la boucle pendant `movestart…moveend`/`zoomstart…zoomend` (l'attribut `data-mouvement` existe déjà, `diorama_controller.js:376`) ; ne pas repeindre ce qui n'a pas bougé (rectangles sales) ; limiter les mobiles visibles ; mettre en cache les sprites par échelle, déjà partiellement fait par `spriteDe` ; interrompre hors vue (onglet, volet fermé) ; vérifier l'effet de `save`/`restore`/`clip` répétés par mobile.

### 2. Marqueurs HTML animés — impact fort
- **91 éléments** de marqueur au chargement (70 pins + 21 bouquets), 140 `<img>` ; 220 points embarqués dans la page (`data-diorama-points-value` : 176 opportunités + histoires).
- Chaque pin porte une animation CSS **infinie** (`pin-respire`, `accueil.css:499`) et le picto trois `drop-shadow` empilés (`accueil.css:~509`), recalculés à chaque image ; les « aujourd'hui » ont en plus `pin-rdv-lueur`. Les marqueurs sont reconstruits à chaque `zoomend` (`dessinerPins`).
- Mesure : **masquer le seul volet des marqueurs fait passer le repos de 5,6 à 11,7 FPS (×2)** et le glissement de 5,7 à 7,5 FPS (+30 %), bridage ×4.
- **Regroupement** : il existe (`diorama/bouquets` : 21 bouquets pour les points proches, sans Leaflet.markercluster), donc **ce n'est pas l'absence de clustering** qui pose problème ; en revanche le regroupement ne limite pas le coût par élément. Il n'y a pas non plus de plafond de marqueurs affichés pour les non regroupés.
- Pistes : mettre `animation-play-state: paused` (ou retirer `pin-respire`) pendant le mouvement et pour les pins hors vue, ou ne l'appliquer qu'aux fiches du jour ; remplacer les trois `drop-shadow` par une ombre pré-calculée dans l'image du pin ou un seul filtre ; `contain: layout paint` sur les marqueurs ; ne pas détruire/recréer les marqueurs inchangés au `zoomend` ; abaisser le seuil de regroupement.

### 3. Tuiles et couches Leaflet — impact modéré
- 15 tuiles canvas `leaflet-tile` visibles (`couches.js` : contour, masque, `getImageData`). Masquer le volet des tuiles seul : repos 5,6 → 7,0 FPS, glissement inchangé : coût **modéré**.
- Tout masquer sauf les tuiles (canvas + marqueurs) : 10,8 FPS au repos, 11,1 au glissement bridé, soit **le plancher de la carte seule**, déjà en dessous de 15 FPS à ×4.

### 4. Réseau — pas de problème sur le zoom/déplacement, un problème de poids au chargement
- Tuiles R2 : `Cache-Control: public, max-age=31536000, immutable`, WebP de **14 à 19 Ko** (échantillon). Sur la séquence (cache chaud) : 13 requêtes en zoom avant, 150 en déplacement, 1 en zoom arrière, 2 au rejeu, **toutes servies par le cache, 0 octet transféré**, **aucune tuile demandée deux fois** (166 distinctes). Il n'y a pas de re-téléchargement ni de débounce nécessaire, Leaflet n'émet que les tuiles nouvelles.
- Chargement à froid : ~254 tuiles ≈ **4-5 Mo estimés** (14-19 Ko chacune ; le compteur CDP n'a pas donné d'octets exacts pour les tuiles) + 3 photos de fiches non optimisées : **5,1 Mo** (deux PNG générés de 2,2 Mo et 2,1 Mo + un JPEG de 0,7 Mo) + ~2,2 Mo d'autres ressources (sprites, JSON). Hors zoom/déplacement, mais lourd pour un premier affichage ; au zoom arrière, une photo de 474 Ko s'est chargée.
- Pistes : redimensionner/convertir en WebP les photos servies sur l'accueil (variantes Active Storage) ; précharger les niveaux voisins n'est pas utile.

### 5. devicePixelRatio non plafonné — impact secondaire, à surveiller
- `mobiles.js:379` (`window.devicePixelRatio || 1`), `vivants.js:396` et `vivants.js:547` : aucun plafond. À DPR 2 les deux canvas passent de 970 × 696 à **1940 × 1392** (4× les pixels), et les sprites sont régénérés à cette échelle.
- Mesuré bridé ×4 : 6,3 FPS au repos et 5,1 au glissement à DPR 2, contre 5,6 et 5,7 à DPR 1 : **écart dans le bruit**, car le goulot est le CPU/JS ; l'effet sera plus net sur un GPU intégré petit avec un écran HiDPI ou une mise à l'échelle Windows à 150 %, **non testé**.
- Piste : `dpr = Math.min(window.devicePixelRatio, 1.5)` pour les canvas animés ; les sprites restent nets, les trains sont petits.

### 6. Hausse du nombre de marqueurs (85 fiches publiées le 01/11) — contributeur, pas cause unique
- Production : **176 opportunités**, dont 85 `source: veille` ; avant : **91**. Les 85 sont toutes géolocalisées, 169 sont `publiques` (fenêtre des petites manifestations). Points embarqués : 220, soit **≈ +63 % vs ≈ 135** avant (estimation : 220 − 85).
- Le comparatif « avant » **n'a pas pu être mesuré** (aucun état antérieur déployé à tester ; la review app n'a pas les mêmes données). Le test de masquage des marqueurs montre que leur coût compte (×2 au repos), donc la hausse a **probablement aggravé** la lenteur, mais la boucle canvas (point 1) existait avant et suffit à elle seule à tenir la page sous 10 FPS bridée.

## Ordre de correction suggéré
1. Pause/réduction des boucles canvas pendant les gestes et au repos si rien ne bouge (gain attendu le plus large).
2. Animations et ombres des marqueurs (gain mesuré ×2 au repos).
3. Plafond de devicePixelRatio, optimisation des photos d'accueil.
4. Tuiles/couches : rien d'urgent.

## Reproduire
Scripts Playwright jetables (non versionnés) : voir l'historique de la session ; les mesures utilisent `https://www.declic.site/`, 1366 × 768, ×1 et ×4. Pas de commit nécessaire (aucune modification de code).

---

# Correctifs appliqués (02/11/2026, commits `d04bb29`, `d1c35ed`, `cd3ba6e`, testés sur la review app, PAS en production)

## Ce qui a changé
1. **Toiles animées** (`vivants.js`, `mobiles.js`, nouveau `diorama/densite.js`) : 30 images/s au repos, **12 pendant un geste** de carte (`data-mouvement`) ; la toile est recalée avec chaque repeinte, entre deux ses mobiles restent posés sur le sol de la carte. Une image identique à la précédente (même vue, mobiles déplacés de moins d'un quart de pixel d'appareil, aucun train à peindre) n'est ni effacée ni repeinte. **Cadence adaptative** : intervalle = max(base, 2 × durée de la dernière repeinte, 3 × pendant un geste), plafonné à 8 images/s (n'a aucun effet sur un poste rapide). Boucles **arrêtées quand la carte sort de l'écran** (`IntersectionObserver`, toile vidée), déjà arrêtées onglet masqué.
2. **Marqueurs** (`accueil.css`, `diorama_controller.js`) : la respiration (`pin-respire`) ne reste que sur les initiatives du jour (la pause pendant les gestes existait déjà) ; **un seul `drop-shadow`** (de jour : halo blanc ; de nuit : halo chaud unique au lieu de trois dont un de 12 px plus un filtre sur chaque bouquet) ; `dessinerPins` ne fait plus rien si les groupes sont identiques et ne retire/ajoute que les pins et bouquets qui changent (bouquets réutilisés avec leurs ancres).
3. **devicePixelRatio** plafonné à 1,5 pour les toiles animées (`dprToiles`, `mobiles.js`, `vivants.js` ×2).

## Mesures, review app (31 marqueurs sur les 99 fiches copiées, 1366 × 768, 3 passes par cas, FPS rAF)

| | Avant | Après |
|---|---|---|
| Sans bridage, repos | 37 / 44 / 56 | 37 / 43 / 55 |
| Sans bridage, glissement | 29 / 30 / 32 | 27 / 44 / 46 (39 en moyenne, +30 %) |
| Sans bridage, zoom | 34 / 47 / 55 | 51 / 53 / 57 |
| **Bridé ×4, repos** | 5,6 / 6,9 / 7,9 | **7,4 / 18,6 / 21,9** |
| Bridé ×4, glissement | 5,1 / 5,8 / 6,2 | 6,1 / 6,5 / 8,6 (+25 %) |
| **Bridé ×4, zoom** | 6,6 / 7,5 / 8,3 | **4,9 / 17,3 / 19,4** (un point isolé à 4,9) |
| Animations CSS en cours | 91 | 31 |

Bruit élevé (les écarts entre passes d'un même cas atteignent 2×) : lire les moyennes comme des ordres de grandeur. Une première version (30 images/s au repos, sans cadence adaptative) donnait 6,8 / 5,7 / 7,5 FPS bridé ×4 : le gain principal à ×4 vient de la cadence adaptative et de la baisse des animations.

## Reste lent, non traité
- **Glissement bridé ×4 : 6-9 FPS.** Profil CPU pendant le glissement : `poserCalque` (calcul des positions des vivants) ≈ 3 s, `save`/`drawImage`/`getImageData` ≈ 20 %, `trains.js` 5 %. Chantier suivant : réduire le calcul de pose (cache des segments vus déjà présent, `majVus`), limiter les mobiles à l'écran, ou geler le calque de vivants pendant tout le glissement. Hors périmètre ici.
- Tuiles/couches Leaflet et photos non touchées, comme demandé.
- Aucune mesure sur la production : la review app n'a que 99 fiches copiées (31 marqueurs affichés) contre 176 en production ; le gain attendu sur les marqueurs y est plus fort.

## Vérifications de comportement (review app)
- Zoomé : `vivants` repeint ~18 fois/s et `mobiles` ~13 fois/s au repos (cadence adaptative sur ce poste) ; pendant un glissement 10,8 images/s ; **0 appel de dessin carte hors écran**, reprise au retour.
- Aucune erreur JS (3 séries de mesures). Captures avant/après : marqueurs lisibles, ombre sombre légèrement moins marquée de jour.
- Tests : 477 unitaires verts ; système 34 : `calques_test.rb:112` échoue aussi sur le code d'avant (aucune tuile canvas chargée dans cet environnement), `ambiances_test.rb:58` intermittent et vert seul.

---

# Mise en production (02/11/2026, `439c691`, release v24 de `declic-nancy-paris-eu`, app US intacte en v369)

Mesures sur www.declic.site (1366 × 768, 3 passes par cas) : 220 points embarqués, **91 éléments de marqueur affichés (70 pins + 21 bouquets)** au chargement, 6 initiatives « du jour » animées.

| | Audit (avant) | Production (après) |
|---|---|---|
| Sans bridage, repos | 43 FPS | 53 / 50 / 56 |
| Sans bridage, glissement | 20 FPS | 31 / 28 / 44 |
| Bridé ×4, repos | 5-9 FPS | **17 / 25 / 24** |
| Bridé ×4, glissement | 4-6 FPS | 5,6 / 7,5 / 7,7 |

- Le gain observé sur la review app se **confirme** en production au repos et sous bridage ; le glissement bridé ×4 gagne peu (6-8 FPS).
- **Correction** : les colonnes « zoom » des mesures de la review app et de la production viennent d'une molette seule, qui ne zoome pas la carte (le zoom exige Ctrl+molette) : à ignorer. Le zoom réel (Ctrl+molette, niveau 6 → 9) a été vérifié visuellement : piétons et voitures présents et en mouvement entre deux captures ; au chargement, 183 voitures, 201 vélos et 6 bus peints (niveau 6).
- `document.getAnimations()` compte encore ~84 animations : 70 sont des `pin-apparait` terminées (remplissage `both`), seules 6 `pin-respire` et 6 `pin-rdv-lueur` tournent.
- 0 erreur JS ; une seule ombre `drop-shadow` sur tous les marqueurs ; canvas 970 × 696 (DPR 1 sur ce poste).
