# Audit du diorama — animations et mobiles existants

Dépôt Déclic, branche `main`, commit `b75b4ad` (2026-11-03). Constat tiré du code, aucune ligne modifiée.
Périmètre lu : `app/javascript/diorama/*.js` (17 fichiers), `app/javascript/controllers/diorama_controller.js`,
`app/models/diorama_tuiles.rb`, `app/services/trains/`, `app/assets/stylesheets/accueil.css`.

**Limite du constat.** Les sprites, modèles et calques d'itinéraires (`vivants-v2`, `mobiles-v6`, `trains-v1`,
`nuit-chaude-v1`) vivent sur R2 / dans nancy-3d, pas dans ce dépôt. Je n'ai pas ouvert ces jeux : « absent » veut dire
« aucune branche de code, aucun nom de modèle, aucun réglage ne le mentionne ». Un sprite non référencé par le code
pourrait exister dans un atlas sans jamais être tiré. De même, `ambiance.js` (shader) n'est lu que sur ses 200 premières
lignes ; le reste a été vérifié par recherche de mots-clés (aucune horloge n'y entre, voir § 3).

---

## 1. Verdict sur les neuf pistes

> **Mise à jour du 03/11/2026 (soir)** : les pistes 4 (en partie) et 9 et une piste hors liste, les ombres de nuages,
> sont passées d'« absent » à « existe ». Le constat ci-dessous (§ 2 et § 3) reste celui du commit `b75b4ad` ; ce qui
> a changé depuis est décrit au § 5.

| # | Piste | Verdict | Où |
| --- | --- | --- | --- |
| 1 | Trains sur les voies ferrées | **Existe, complet** | `trains.js`, `trains_reels.js`, `Trains::Prochains` |
| 2 | Vélos en libre-service (stations) | **Absent** (vélos classiques seulement) | `vivants.js` |
| 3 | Oiseaux | **Absent** (un glyphe fixe sur la page d'accueil, hors diorama) | `_silhouette.html.erb:28` |
| 4 | Joggeurs / promeneurs de chien dans les parcs | **Existe en partie** depuis le 03/11 : joggeurs oui, promeneurs de chien non (aucun sprite de chien) | `vivants.js` |
| 5 | Marché ponctuel (stands temporaires) | **Absent** | — |
| 6 | Terrasses de café selon l'heure | **Absent** | — |
| 7 | Feux d'artifice / illuminations à dates fixes | **Absent** (éclairage nocturne permanent, saison par mois) | `lampadaires.js`, `soleil.js` |
| 8 | Pluie animée | **Existe** (pluie et neige, météo réelle) | `precipitations.js`, `meteo.js` |
| 9 | Brouillard matinal | **Existe** depuis le 03/11 (météo réelle, codes WMO 45 et 48) | `voiles.js`, `meteo.js` |
| — | Ombres de nuages (hors liste) | **Existe** depuis le 03/11 (météo réelle, codes WMO 2 et 3, de jour) | `voiles.js`, `meteo.js` |

---

## 2. Inventaire de l'existant

Tout est posé sur la carte Leaflet dans des volets (`z-index` croissant) : dalles 200 → halo 250 → bateaux 440 →
vivants et trains 445 → tilt-shift 448 → météo 450 → pins 600.

### 2.1 Piétons — `vivants.js`

- **Quoi.** Sprites cuits pour la caméra du diorama (50°, azimut 200°), posés sur les trottoirs, passages, escaliers et
  bords (`DENSITE_PIE = [30, 30, 40, 15, 20]` par km et par sens, une valeur par classe de voie).
- **Mouvement.** Position = fonction de l'heure : `phase + k·Δ + gigue + t`, modulo la durée du parcours. Vitesse
  1,1 à 1,5 m/s tirée par itinéraire. Marche à deux sprites (`-g` / `-d`) alternés toutes les 0,7 m. Décalage latéral
  tiré à la graine (trottoir, côté), fondu de 10 m aux extrémités des itinéraires non bouclés.
- **Courbe horaire** (`COURBES.pieton`, ancres [heure de Nancy, facteur]) : 0:00 → 0,10 · 5:00 → 0,04 · 7:00 → 0,30 ·
  9:00 → 0,60 · 12:00 → 1,00 · 14:00 → 0,80 · 17:00 → 0,95 · 18:00 → 1,00 · 20:00 → 0,60 · 22:00 → 0,30 · 24:00 → 0,10.
  Un piéton `k` est gardé si sa graine est sous le facteur : la file garde ses rangs, seuls des mobiles s'effacent.
- **Conditions.** Niveau de zoom ≥ 7 (les autres mobiles dès 6) ; 30 images/s au plus au repos, 12 pendant un geste de
  carte ; suspendu onglet caché ; **aucun** si `prefers-reduced-motion` ou `saveData` ; coupé par `?vivants=0`.
- **Nuit.** Pas de comportement propre : la toile entière est assombrie par un filtre CSS (voir § 3).

### 2.2 Vélos — `vivants.js`

- **Quoi.** Un seul modèle retenu (`MODELE_VELO = "velo-detaille"`), sur les pistes cyclables (classe 0, 20 par km et
  par sens) et les bandes (classe 1, 15), `DENSITE_VELO = [20, 15]`.
- **Mouvement.** Même moteur que les piétons, vitesse 4 à 5 m/s tirée par itinéraire, file écrite par le calque (`v[6]`).
- **Courbe horaire.** 0:00 → 0,04 · 5:00 → 0,02 · 7:00 → 0,50 · 8:00 → 0,90 · 10:00 → 0,50 · 12:00 → 0,70 · 14:00 → 0,55 ·
  17:00 → 0,90 · 18:00 → 1,00 · 20:00 → 0,40 · 22:00 → 0,15 · 24:00 → 0,04 (deux pointes : 8:00 et 18:00).
- **Conditions.** Niveau ≥ 6, taille figée au niveau 8 en dessous (`tailleFigee`).

### 2.3 Voitures — `vivants.js`

- **Quoi.** Voitures sur les voies routières par classe : vitesses `[25, 13, 11, 9, 7, 4]` m/s (autoroute → rue partagée),
  densités `[12, 14, 12, 9, 5, 2]` par km et par file. Un modèle tiré à la graine du mobile dans `parType.voiture`.
- **Courbe horaire.** 0:00 → 0,12 · 5:00 → 0,08 · 7:00 → 0,60 · 8:00 → 0,95 · 10:00 → 0,70 · 12:00 → 0,80 · 14:00 → 0,75 ·
  17:00 → 0,95 · 18:00 → 1,00 · 20:00 → 0,55 · 22:00 → 0,30 · 24:00 → 0,12.
- **Conditions.** Niveau ≥ 6 (taille figée à ×0,5 en dessous).

### 2.4 Bus et trolleybus — `vivants.js`

- **Quoi.** Deux calques (`bus.json`, `trolleybus.json`), lus **seulement si** `modeles-vivants.json` porte les modèles
  `bus-detaille-v2` / `trolleybus-tempo1-v2` (jeu `vivants-v2`). Vitesse 7 m/s sur chaussée, 8 m/s en voie réservée.
- **Mouvement.** Le flux n'est pas une densité mais la **fréquence de la ligne** (`itineraires_bus_par_heure` du calque,
  ÷ 3 600) ; passages à intervalles réguliers. Arrêts non marqués (décision notée dans l'en-tête, § 16.2 de nancy-3d).
- **Service** (`SERVICE_BUS`, paliers) : 0:00–0:30 → ½ des passages · 0:30–5:00 → **aucun** · 5:00–6:30 → ½ ·
  6:30–20:30 → tous · 20:30–24:00 → ½. Le « ½ » se fait en gardant un passage sur `round(1/f)`.
- **Courbe plausible, pas une donnée** (aveu de l'en-tête) : aucun comptage ni GTFS n'est branché sur les bus.
- **Conditions.** Niveau ≥ 6, 24 px de plancher, coupé par `?vivants-bus=0`.

### 2.5 Bateaux, péniches — `mobiles.js`

- **Quoi.** Péniches sur le canal, petits bateaux sur la Meurthe (tirage commun depuis le 15/10 : un bateau peut avoir
  n'importe quel modèle sur n'importe quelle voie). Calque `bateaux.json` + atlas `sprites-bateaux.png`.
- **Mouvement.** Sur chaque intervalle de circulation, bateaux régulièrement espacés (`DENSITE = [6, 2]` par km et par
  file : péniches, petits bateaux), une file par sens quand l'eau fait ≥ 12 m, une seule sinon. Vitesse `[1,0 ; 1,6]` m/s
  (±10 % par file, donc pas de dépassement). Fondu de 15 m aux bouts, à l'approche d'une portion couverte et contre la
  berge peinte. **Sillage** : traits fins en 5 crans d'opacité, retiré sous les ponts et arbres.
- **Occlusion.** Masqués colonne par colonne par la carte de propriété (pont, arbre) ; un correctif `occlusion-jv2.json`
  redonne le sol à l'eau sous les houppiers effacés du style `jeu-video-v2`.
- **Bateaux à quai.** `amarrages.json`, facultatif, nommé par le manifeste : postes fixes, **présents à toute heure**
  (« le port ne s'anime plus mais reste visible »), passerelle dessinée à partir du niveau 9.
- **Courbe horaire** (`COURBE_NAVIGATION`) : 0:00–6:00 → 0,08 · 8:00 → 0,40 · 10:00 → 0,80 · 12:00–17:00 → 1,00 ·
  19:00 → 0,60 · 21:00 → 0,15 · 22:00–24:00 → 0,08. **Plancher de 0,08 posé le 03/11/2026** (commit `b75b4ad`) : avant,
  zéro bateau en marche la nuit. La cadence de ce filet reste à mesurer machine au repos, d'après le message du commit.
  « Courbe plausible, pas une donnée » (horaires d'écluses VNF non branchés).
- **Conditions.** Niveau ≥ 6, masque au sol construit dès 7 ; 30 images/s au plus ; coupé par `?mobiles=0`.

### 2.6 Trains — `trains.js`, `trains_reels.js`, `Trains::Prochains` (Rails)

Seule animation à **état** (les autres sont des fonctions pures de l'heure) : les rames avancent d'un pas fixe de 0,5 s
(`reglages.pas_s`) et leur position est interpolée entre deux pas.

- **Physique.** Profil de vitesse limite au mètre (arête, matériel, 40 km/h en déviation), traction à puissance bornée,
  freinage de service, à-coup borné, courbe de freinage vers chaque limite à venir et vers l'arrêt en gare.
- **Cantonnement.** Cantons coupés aux zones d'aiguille et tous les 300 m (`canton_m`), accordés devant la rame ; une rame
  attend (« au signal ») si un canton est tenu. Garde-fou : deux rames dont les caisses se touchent → recul et arrêt,
  compté dans `stats.gardeFou` (doit rester à 0).
- **Deux modes, aiguillés par `aiguiller()` :**
  1. **Horaires réels** : le relais Rails `GET /trains/prochains.json` (`Trains::Prochains` : GTFS théorique des passages à
     Nancy-Ville affiné par GTFS-RT, fenêtre 10 min passé / 30 min futur) est interrogé toutes les 60 s ; chaque passage
     devient une fiche (quai choisi parmi ceux que la géométrie permet, **voie à quai non publiée**, donc plausible, pas
     réelle) ; la rame apparaît `A − t_arret` avant l'arrivée, attend à quai (20 à 240 s), repart. Scène préjouée de 420 s
     pour que les trains déjà en route soient à leur place. Catégorie `tgv` → rame TGV, tout le reste → rame TER.
  2. **Boucle de démonstration** : scénarios `gare` puis `ligne_droite` rejoués en boucle avec 3 s de scène vide, fondus
     d'entrée (2 s) et de sortie (120 m). **Elle ne dépend pas de l'heure** : elle tourne la nuit comme le jour dès que
     le relais ne promet aucun train dans les 180 s (ou qu'il est injoignable).
- **Bascule.** La boucle s'efface en fondu quand un vrai train est attendu dans 6 s ; elle revient quand rien n'est
  attendu dans 180 s.
- **Conditions.** Style `jeu-video-v2` seulement (pose et occlusion calées dessus) ; niveau ≥ 6 ; la vue doit recouper
  l'emprise du réseau ; les données (≈ 9 Mio) ne se lisent qu'à la première vue du réseau ; coupés par `?trains=0`
  (tout) ou `?trains-reel=0` (boucle seule) ; `?trains-heure=HH:MM` rejoue les horaires d'une heure (essais).
- **Incohérence à corriger** : l'en-tête de `trains.js` (lignes 3–4) dit « PAS branché sur /labo/diorama : ce module n'est
  importé par aucune page ». C'est faux depuis le commit `118f31a` : `diorama_controller.js:21` l'importe et
  `:1057–1060` le construit sur l'accueil.

### 2.7 Pluie et neige — `precipitations.js`, `meteo.js`

- **Source.** Mode automatique : Open-Meteo (`current=weather_code` à 48.6937, 6.1834), code WMO traduit en `clair` /
  `pluie` / `neige` (`AUTO.codes_pluie`, `codes_neige`) ; réponse gardée 30 min en `localStorage` ; **repli silencieux
  sur « clair »** si réseau, délai (5 s) ou réponse en échec. Renouvelée par la minuterie de 60 s du contrôleur (appel
  réellement émis au plus toutes les 30 min). Le visiteur peut aussi forcer la météo à la main.
- **Rendu.** Un canevas de particules dans le volet `meteo` (450), recalé à chaque déplacement. Pluie : 180 gouttes à
  1920 × 1080 (proportionnel à la surface de la carte), trois plans de profondeur (455–680 px/s, traits de 28 à 48 px,
  inclinés). Neige : 300 flocons, trois plans, dérive sinusoïdale. Le flou de chaque plan est précalculé une fois par plan.
  Les particules naissent au hasard (`Math.random`) : deux visites ne rendent pas la même pluie.
- **Effets annexes (shader d'ambiance).** Pluie : sol plus sombre et plus contrasté, léger voile d'assombrissement
  (`pluieVoile`). Neige : toits blanchis via le masque du bâti.
- **Conditions.** 30 images/s au plus, suspendue onglet caché, **aucune particule** sous `prefers-reduced-motion`, tailles
  réduites en écran étroit (< 700 px), seulement en mode diorama hors maquette blanche.
- **Non couplée aux mobiles** : `vivants.js`, `mobiles.js` et `trains.js` ne lisent pas la météo (aucune réduction de
  piétons ou de vélos sous la pluie).

### 2.8 Cycle jour / nuit, saisons

- **Moment** (`soleil.js`, `momentAuto`) : calcul astronomique local (formules NOAA), hauteur du soleil à Nancy :
  ≥ 6° → `jour` · 0° à 6° → `heure-doree` · −8° à 0° → `aube` (matin) ou `heure-bleue` (soir) · < −8° → `nuit`.
  Recalculé toutes les 60 s (`minuterieAuto`). Un choix manuel du visiteur expire quand le ciel change de moment.
- **Saison** (`saisonAuto`) : par mois à Nancy — octobre, novembre → `automne` ; décembre, janvier, février → `hiver` ;
  le reste → `printemps-ete`. L'automne teinte les houppiers du jaune au roux (une cellule de Voronoï par arbre, fixe au
  sol) ; l'hiver applique l'étalonnage publié.
- **Ambiance** (`ambiance.js`) : un étalonnage WebGL par dalle, qui remplace la couche de fond. **Aucune horloge dans le
  shader** : une recherche de `uTemps`, `Date.now`, `performance.now` et `requestAnimationFrame` dans `ambiance.js`,
  `couches.js` et `vue.js` ne rend rien. Rien n'y scintille, ne dérive ni ne respire.
- **Mobiles la nuit.** Les sprites sont cuits en plein jour ; leur toile reçoit un filtre CSS (`TEINTES_VIVANTS`) :
  aube `brightness(0.85) saturate(0.85)` · heure dorée `brightness(0.9) sepia(0.15)` · heure bleue
  `brightness(0.65) saturate(0.7)` · nuit `brightness(0.45) saturate(0.6)`. Appliqué aux vivants, aux trains (même toile)
  et aux bateaux. Pas de phares, de feux arrière ni de fenêtres de tram.

### 2.9 Éclairage nocturne — `lampadaires.js`, `reglages.js` (`LAMPADAIRES`)

- **Quoi.** Lampadaires (lanternes Géonancy si publiées, sinon positions procédurales BD TOPO), flaques de lumière des
  places (`flaques-places.json`, `nuit-chaude-v1`), façades réchauffées depuis leur pied, fenêtres allumées par bâtiment
  (part 0,08 à 0,85, 15 % de bâtiments tout éteints), halo flouté.
- **Intensité** (`LAMPADAIRES.intensite`) : `nuit` → 1 · `heure-bleue` → 0,4 · tout autre moment → aucune lumière.
- **Statique.** Le tirage des fenêtres est fixe par bâtiment : aucune fenêtre ne s'allume ni ne s'éteint au fil de la
  soirée. Les lampadaires ne vacillent pas.

### 2.10 Éléments animés hors diorama « monde »

- **Pins de la carte** (`accueil.css`, `bouquets.js`) : respiration (`pin-respire`, 2,8 à 3,6 s, période tirée de
  l'identifiant du point) **et** lueur (`pin-rdv-lueur`, 2,4 s) **uniquement sur les initiatives du jour**
  (`.acc-aujourdhui`) — la respiration permanente de tous les pins a été retirée parce qu'elle coûtait la moitié des
  images (`rapports/perf-carte-2026-11-02.md`). Apparition (`pin-apparait`, 420 ms), rebond et onde à la sélection.
- **Tilt-shift** (`vue.js`, classe `TiltShift`) : flou progressif en haut et en bas de l'écran, par empilement de volets
  `backdrop-filter` ; effet de vue, statique. Coupé par `?tilt=0`.
- **Halo nocturne** (`haloMode`) : flou de l'émission, par dalle (réglage en vigueur) ou par volet (`?halo=vue`).

### 2.11 Garde-fous communs aux toiles animées

`prefers-reduced-motion` (bateaux, vivants, précipitations : retirés ; trains : portés par la toile des vivants),
`saveData` (vivants), onglet caché (suspendu), carte hors vue (`pauseHorsVue`), cadence adaptée au coût de la repeinte
(`intervalleAdapte`, `lisserCout`), signature d'image (aucun repeint si rien n'a bougé d'un quart de pixel — **sauf**
quand un train est à peindre : il rend la signature `null`, donc la toile se repeint à chaque image tant qu'une caisse est
visible).

### 2.12 Crochets d'instrument (URL)

`?vivants=0`, `?vivants-t=S` (horloge figée), `?vivants-heure=H|pointe`, `?vivants-densite-velo=P,B`, `?vivants-bus=0` ·
`?mobiles=0`, `?mobiles-t=S`, `?mobiles-heure=H|pointe`, `?mobiles-banc=1`, `?mobiles-densite=P,B` et les planchers ·
`?trains=0`, `?trains-reel=0`, `?trains-heure=HH:MM` · `?tilt=0`, `?halo=0|vue|dalle`.

---

## 3. Constat détaillé sur les neuf pistes

### 1. Trains — existe, complet

Voir § 2.6. Deux points qui comptent pour la suite : la boucle de démonstration tourne à toute heure (un train de
démonstration peut donc traverser la scène à 3:00 du matin sans vrai horaire), et la voie à quai affichée est un choix
plausible, pas l'information SNCF.

### 2. Vélos en libre-service — absent

Aucune occurrence de station, borne, dock, `libre-service`, `vélostan` ou équivalent dans `diorama/`, le contrôleur, les
vues ou la configuration. Les seuls vélos sont des mobiles en mouvement sur pistes et bandes (§ 2.2), un modèle unique
(`velo-detaille` ; `vivants.js:212` écarte tout autre modèle de type `velo`). Une station serait un objet **fixe**, de la
famille des bateaux à quai (`amarrages.json`, postes déclarés dans nancy-3d) : `mobiles.js` est le seul précédent de poste
fixe dans le code.

### 3. Oiseaux — absent

Aucun oiseau, pigeon ni mouette dans le diorama. Seule occurrence : un `<path>` SVG décoratif (commentaire ERB « oiseaux », deux petits
« v » à `accueil/_silhouette.html.erb:28`) dans la frise de silhouette de la page d'accueil, sans animation (aucun
`@keyframes` ne la vise).

### 4. Joggeurs / promeneurs de chien dans les parcs — absent

Les piétons (§ 2.1) sont génériques et sans notion de parc : leurs classes de voie sont trottoir, passage, piéton,
escalier, bord ; leur vitesse est celle d'une marche (1,1 à 1,5 m/s), un joggeur (≈ 2,5 à 3 m/s) n'existe pas, il n'y a
aucun modèle ni branche de code pour un chien, et `vegetation.geojson` n'est lu que par l'extraction nancy-3d, jamais par
Déclic. Le filtre de `vivants.js:212` n'écarte que les poses de piéton négatives (`m.pose < 0`) ; il n'exclut aucune
espèce de modèle, donc le contenu de `modeles-vivants.json` (R2) reste à vérifier si l'on veut être catégorique sur les
sprites.

### 5. Marché ponctuel — absent

Aucun stand, étal ni calque lié à un jour de la semaine ou à une date. Le seul « calendrier » du code est celui des fiches
d'initiatives (`dates.js`) : il pilote le texte des cartes (« Aujourd'hui », « Demain ») et la respiration des pins du
jour. La famille d'événements « Brocantes, foires et fêtes » existe comme **catégorie de pins masquée par défaut**
(`diorama_controller.js:1437`) : c'est de la donnée éditoriale, pas un décor animé ou posé sur la maquette.

### 6. Terrasses de café — absent

Aucune terrasse, aucun mobilier de rue, aucun mobile fixe lié à l'heure. La seule occurrence de « terrasse » est un
commentaire (`reglages.js:68`) qui rappelle l'ancien nom d'un étalonnage de nuit (« Terrasse du café le soir »).
Les piétons suivent leur courbe horaire globale (§ 2.1), sans point d'intérêt qui les attire.

### 7. Feux d'artifice / illuminations à dates fixes — absent

Aucune logique de date de fête (14 juillet, Saint-Nicolas, Noël, etc.). Les dates ne servent qu'à trois choses : le **mois**
choisit la saison (§ 2.8), la **hauteur du soleil** choisit le moment, et le **jour** étiquette les fiches. Les éclairages
sont ceux de la rue, constants de l'heure bleue à l'aube (§ 2.9). Aucun module de particules lumineuses n'existe ;
`precipitations.js` ne sait faire que pluie et neige.

### 8. Pluie animée — existe

Voir § 2.7. Détail utile : c'est la météo **réelle** de Nancy (Open-Meteo), pas une saison ni un horaire ; elle peut être
forcée à la main ; elle n'agit que sur le sol, les toits et les particules, jamais sur le trafic.

### 9. Brouillard matinal sur la Meurthe / le canal — absent

Rien : ni code météo WMO de brouillard (les listes `codes_pluie` et `codes_neige` s'arrêtent à 99 et 86 ; les codes 45 et
48 d'Open-Meteo, brouillard et brouillard givrant, tombent donc dans `clair`), ni calque d'eau animé, ni dégradé de profondeur,
ni champ de bruit. Les deux « voiles » du code sont d'une autre nature : `pluieVoile` assombrit la carte pendant la pluie
et le `voile` du moment de nuit est un étalonnage de couleur, tous deux fixes. L'eau (Meurthe, canal) n'est qu'un sol du
point de vue de la carte de propriété ; l'ambiance la reconnaît à sa teinte (`eau()` dans le shader) uniquement pour
l'épargner de la lumière dorée des quais.

---

## 4. Ce que le code permet d'observer pour la suite (sans rien proposer)

- **Un seul patron d'animation « monde » existe pour les mobiles** : position = fonction pure de l'heure + graine, avec un
  facteur horaire par famille et une occlusion par la carte de propriété. Les trains en sont l'exception (état + pas fixe).
- **Aucun objet fixe animé n'existe** hors bateaux à quai (qui ne bougent pas, la nuit comme le jour).
- **La météo n'est couplée à rien d'autre qu'au sol et aux toits.**
- **Les facteurs horaires sont des courbes « plausibles, pas des données »** (bus, bateaux, piétons, vélos, voitures) ;
  seuls les trains lisent un horaire réel.
- **Nuit : une seule transformation commune** (filtre CSS sur les toiles), sans phares ni fenêtres de véhicules.
- **Un coût à garder en tête** : le trafic de trains désactive la mise en cache de l'image de la toile des vivants
  (signature `null`), et le journal de perf du 02/11 a déjà retiré une animation permanente pour son coût
  (`rapports/perf-carte-2026-11-02.md`).

---

## 5. Ce qui a été ajouté le 03/11/2026 (après le constat)

**Météo.** `meteoDuCode` rend désormais cinq valeurs : `clair`, `nuageux` (WMO 2, 3), `brouillard` (45, 48), `pluie`,
`neige` (avant : 2, 3, 45 et 48 tombaient dans `clair`). Le 1, « principalement dégagé », reste clair. Le panneau Ambiance
gagne les puces « Nuageux » et « Brouillard » (forçage à la main). Nuages et brouillard ne touchent **pas** la dalle : la
couche d'ambiance est celle de la météo du sol (`meteoDuSol`), aucune dalle n'est recalculée.

**Ombres de nuages et brouillard — `voiles.js`.** Deux toiles dans le volet `meteo` (450), sur le patron de
`precipitations.js`, mais **ancrées au sol et dimensionnées en mètres** (une ombre est posée sur la maquette, la pluie
tombe devant) : repère de grille Lambert-93 tiré de `diorama_projection`, motif périodique tiré à la graine, dérive à
l'heure absolue (mêmes nuages pour tous). Toile peinte au quart (nuages) ou au tiers (brouillard) de l'écran puis étirée,
15 images/s, suspendue onglet caché ou carte hors écran, masquée pendant un zoom, fondu d'opacité CSS de 2,5 s à
l'apparition, au retrait et à chaque changement de force.
- Nuages : jour (force 1) et heure dorée (½) seulement ; vent fixe vers 70° de grille, 8 m/s (le vent réel n'est pas lu).
- Brouillard : voile + eau plus épaisse (itinéraires des bateaux de `mobiles.js`, élargis de 35 m de berge) + nappes
  claires qui dérivent ; les volumes (bâti, houppiers, carte de propriété déjà lue par les bateaux, dès le niveau 7)
  percent le voile. Force = f(hauteur du soleil) : 1 sous l'horizon, 0,3 au-dessus de 18°, interpolation douce ; ×0,7 la
  nuit. **Écart à la demande** : l'eau n'est pas reconnue par `eau()` du shader (une détection de teinte calculée sur la
  dalle, illisible depuis une autre toile sans relecture GPU) mais par la géométrie des bateaux, la même eau ; sans
  bateaux (`?mobiles=0`), voile uniforme.

**Joggeurs — `vivants.js`.** Un calque `joggeurs` qui partage la géométrie des piétons et a ses propres temps de parcours :
2,5 à 3 m/s (1,4 m/s dans les escaliers), foulée de 1,1 m au lieu de 0,7, même sprite (le jeu `vivants-v2` n'a que deux
poses de marche par modèle, aucune de course). Part prise SUR les marcheurs (l'effectif total ne bouge pas) : 5 % par
classe, 15 % sur les voies piétonnes (proxy des parcs : Déclic ne lit aucun calque de végétation), 8 % en bord. Courbe
horaire propre (matin et soir). Mesuré à la Pépinière, niveau 7, 20 images : 4,9 % des piétons vus à 3 h, 10,4 % à
6 h 30, 8,0 % à 8 h, 3,9 % à 13 h, 8,2 % à 18 h 30, 3,9 % à 21 h 30.

**Crochets** : `?nuages=0`, `?brouillard=0`, `?joggeurs=0` (page d'avant), `?voiles-t=S` (horloge figée des voiles).
