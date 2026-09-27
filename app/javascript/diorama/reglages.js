// LES RÉGLAGES DES AMBIANCES, en un seul endroit : c'est ici qu'on retouche les étalonnages.
//
// Trois réglages indépendants se cumulent sur chaque dalle, dans cet ordre :
//   1. la SAISON (hiver, automne) teinte le paysage ;
//   2. la MÉTÉO (pluie, neige) mouille le sol ou blanchit les toits, et fait tomber des particules ;
//   3. le MOMENT (aube, heure dorée, heure bleue, nuit) éclaire le tout, puis la nuit allume ses lumières.
// L'hiver reprend l'étalonnage publié sur R2 (ambiances/hiver-actuelle.json) ; aube, heure dorée,
// heure bleue et nuit sont des étalonnages paramétriques, définis ci-dessous.

// Étalonnage paramétrique d'un moment, appliqué dans cet ordre :
//   temperature : température de couleur de la lumière, en kelvins (6500 = neutre, moins = plus chaud) ;
//   teinte      : axe vert (−) / magenta (+), de −1 à 1 ;
//   saturation  : 1 = inchangée ;
//   contraste   : 1 = inchangé, autour du gris moyen ;
//   luminosite  : facteur sur la clarté (1 = inchangée) ;
//   voile       : couleur [r, g, b] (0-255) mêlée à l'image, et sa part (0 = aucun voile).
export const MOMENTS = {
  aube: {
    temperature: 5400, teinte: 0.22, saturation: 0.82, contraste: 0.9, luminosite: 0.93,
    voile: { couleur: [236, 196, 214], part: 0.1 }
  },
  "heure-doree": {
    temperature: 4300, teinte: 0.04, saturation: 1.1, contraste: 1.06, luminosite: 1.02,
    voile: { couleur: [255, 196, 120], part: 0.06 }
  },
  // Nuit v7 (« la ville qui brille ») : assombrissement léger (≈ 75 % de la clarté du jour), couleurs
  // locales conservées voire renforcées (toits, ardoises, feuillages restent lisibles) ; le bleu-violet
  // ne vient plus d'un voile plat mais du champ `voile.ombres` (voir ambiance.js) qui ne le pose que
  // dans les zones sombres/non éclairées — les surfaces éclairées (rues, façades, toits) le traversent.
  //
  // Cibles v7b, mesurées sur docs/maquettes/declic-nuit-reference-v1.png (médianes HSV par zone,
  // échantillonnage k-means + seuils de luminosité, script jetable ; H en degrés, S et V de 0 à 1) :
  //   rues éclairées    : H= 47° S=0.55 V=0.97   (or vif, très clair)
  //   façades éclairées : H= 38° S=0.52 V=0.82   (crème doré, un peu moins saturé/clair que la rue)
  //   toits (tuile)     : H= 14° S=0.79 V=0.56
  //   toits (ardoise)   : H=210° S=0.81 V=0.49
  //   ombres            : H=204° S=0.63 V=0.09   (bleu profond, pas violet pur — voir NUIT_CIBLES)
  // Ces cibles pilotent en Lab (via NUIT_CIBLES ci-dessous) la teinte des surfaces éclairées et des
  // ombres dans ambiance.js, à la place de l'ancien mélange RGB « max »/« écran » qui blanchissait les
  // zones où plusieurs nappes se recouvraient (rues et façades viraient au rose pâle). a*/b* (teinte et
  // chroma) : interpolés vers la cible. L* (clarté) : un mix plein aplatissait toute variation locale
  // (pavés, ombres portées) dès que le poids approchait 1 sur une large zone — aplat plat sur la place
  // Stanislas et le carrefour de la gare. L* reçoit donc un LIFT ADDITIF (LAMPADAIRES.nappe/facades.gainL,
  // en points L*) plafonné à la cible : la texture reste visible tant qu'elle ne dépasse pas le plafond.
  // Pour les ombres, on tourne la teinte a*/b* vers cibleOmbre en conservant le chroma du pixel (pas un
  // mix brut des vecteurs, qui délave — leur norme dépend de L* et cibleOmbre est mesurée très sombre) ;
  // les ombres ne touchent pas L*, donc aucun assombrissement supplémentaire.
  // Mesuré sur les recadrages 200 % (Stanislas + gare) après le correctif du lift additif (plus haut) :
  // rues H=47° S=0.51 ; façades H=38° S=0.50 ; ombres H=206° S=0.54 — tous à moins de 8° et 0,1 des
  // cibles ci-dessus (le premier réglage v7b, à base d'un mix plein en L*, les respectait déjà mais
  // aplatissait la place Stanislas et un carrefour de la gare en un bloc uni — voir gainL ci-dessus).
  nuit: {
    temperature: 21000, teinte: -0.1, saturation: 1.28, contraste: 1.08, luminosite: 0.75,
    voile: { couleur: [40, 26, 110], part: 0.88, ombres: true },
    // Parcs et pelouses (pixels de feuillage) : bleu-vert profond, jamais noirs.
    parcs: { couleur: [20, 78, 92], part: 0.4 }
  },
  // Nuit profonde : l'ancien étalonnage v6 (« Terrasse du café le soir »), fond bleu outremer saturé et
  // voile plat, ≈ 60 % de la clarté du jour. Conservé pour compatibilité mais retiré du panneau (absent
  // de la liste des moments dans accueil/calques/_ambiance.html.erb).
  "nuit-profonde": {
    temperature: 22000, teinte: -0.12, saturation: 1.18, contraste: 1.04, luminosite: 0.5,
    voile: { couleur: [14, 36, 178], part: 0.36 },
    parcs: { couleur: [20, 78, 92], part: 0.45 }
  },
  // Heure bleue : la même nuit, fond plus clair, lumières à 40 % (LAMPADAIRES.intensite). Elle prime
  // sur l'étalonnage publié ambiances/heure-bleue-actuelle.json (orangé, pas bleu) ; la retirer d'ici
  // pour y revenir.
  "heure-bleue": {
    temperature: 17000, teinte: -0.12, saturation: 1.1, contraste: 0.98, luminosite: 0.68,
    voile: { couleur: [30, 70, 180], part: 0.24 },
    parcs: { couleur: [34, 100, 110], part: 0.35 }
  }
}

// Heure bleue et hiver : étalonnages publiés, dosés par `force` (1 = tel quel). Celui de l'heure bleue
// ne sert que si MOMENTS["heure-bleue"] est absent.
export const PUBLIES = { "heure-bleue": { force: 1 }, hiver: { force: 1 } }

// Nuit v7b : couleurs cibles de la Lab, converties depuis les médianes HSV mesurées sur la référence
// (voir le commentaire de MOMENTS.nuit). Utilisées par ambiance.js pour teinter en Lab (a*, b*, avec un
// plafond de clarté L*) les rues et façades éclairées, et les ombres — plutôt que le mélange RGB
// « max »/« écran » qui blanchissait les zones de recouvrement (rues et façades viraient au rose pâle).
export const NUIT_CIBLES = {
  rue: [248, 219, 113],
  facade: [208, 168, 101],
  ombre: [8, 17, 22]
}

// L'automne ne teinte QUE les feuillages.
//   Avec la couche masque-arbres (R2) : les pixels du masque, rien d'autre.
//   Sans elle (repli) : les verts sombres et assez saturés, à intensité réduite ; les pelouses,
//   plus claires (valeur HSV ≈ 0,6 contre < 0,5 pour les houppiers), sont préservées.
// La couleur vient de l'étalonnage publié ambiances/automne-actuelle.json (règle « feuillage »),
// puis chaque arbre tire sa propre teinte (du jaune au roux) : cellules irrégulières de la taille
// d'un houppier, fixées au sol, donc stables quand on déplace la carte.
export const AUTOMNE = {
  intensite: 0.9,             // part de l'étalonnage appliquée aux feuillages (0 à 1)
  variation_teinte_deg: 26,   // écart de teinte d'un arbre à l'autre, de part et d'autre de l'orangé
  variation_clarte: 7,        // écart de clarté (L*, 0-100) d'un arbre à l'autre
  taille_arbre_px: 16,        // taille d'un houppier au niveau 8 (≈ 2,26 px par mètre)
  repli: {
    intensite: 0.5,           // moitié de l'intensité ci-dessus
    teinte_min: 75, teinte_max: 165, // verts, en degrés HSV
    saturation_min: 0.12,
    valeur_max: 0.5,          // au-dessus (et jusqu'à valeur_max + 0,08, en fondu) : pelouse claire, préservée
  }
}

// Météo : l'effet sur les dalles, puis les particules (canevas au-dessus de la carte).
//
// Particules : tailles en pixels CSS, pour un écran d'ordinateur ; sur écran étroit (mobile, voir
// ETROIT dans diorama/precipitations), les TAILLES (rayon, longueur, épaisseur, dérive) sont
// réduites à `PARTICULES.echelle_etroit` — pas leur nombre. Le nombre est celui à 1920 × 1080
// (`particules_1920`), mis à l'échelle de la surface réelle de la carte (`PARTICULES.surface_1920`),
// avec un plancher (`PARTICULES.plancher`) pour rester visible sur un tout petit écran.
// Chaque type se répartit en trois plans de profondeur (`plans`, parts qui totalisent 1) : le plan
// le plus proche est le plus gros, le plus flou (canvas `filter: blur(...)`) et le plus rapide.
export const PARTICULES = {
  surface_1920: 1920 * 1080,
  plancher: 10,
  echelle_etroit: 0.7
}

export const PLUIE = {
  sol_luminosite: 0.86, sol_contraste: 1.14, saturation: 0.9, // le sol mouillé, plus sombre et plus contrasté
  volumes_luminosite: 0.95,
  assombrissement: 0.08,       // toute la carte (pixels non exclus), en plus de l'effet ci-dessus
  particules_1920: 180,        // à 1920 × 1080 ; proportionnel à la surface réelle ensuite
  inclinaison: Math.tan(15 * Math.PI / 180), // décalage horizontal par pixel de chute, ≈ 15°
  couleur: "rgba(80, 130, 200, 0.65)",
  lisere_couleur: "rgba(225, 235, 248, 0.55)", // filet clair d'un côté du trait
  lisere_decalage_px: 1,
  plans: [
    { part: 0.45, vitesse_px_s: [455, 505], longueur_px: [28, 34], epaisseur_px: 2, flou_px: 0 },
    { part: 0.35, vitesse_px_s: [505, 585], longueur_px: [34, 41], epaisseur_px: 2.5, flou_px: 0.5 },
    { part: 0.20, vitesse_px_s: [585, 680], longueur_px: [41, 48], epaisseur_px: 3, flou_px: 1 }
  ]
}

export const NEIGE = {
  toits: 0.82,                // blanchiment maximal des toits (masque-bati), progressif selon la pente et le bruit
  sol: 0.14,                  // voile de neige sur le reste
  couleur: [238, 243, 250],
  particules_1920: 300,       // à 1920 × 1080 ; proportionnel à la surface réelle ensuite
  couleur_flocon: "rgba(255, 255, 255, 0.9)",
  contour_couleur: "rgba(60, 70, 90, 0.35)", // contour doux, pour rester visible sur la maquette claire
  derive_px: 15,               // amplitude du balancement horizontal (variation ×0,7 à ×1,3 par flocon)
  plans: [
    { part: 0.40, vitesse_px_s: [26, 34], rayon_px: [3.5, 4.5], contour_largeur_px: 1, flou_px: 0 },
    { part: 0.35, vitesse_px_s: [34, 46], rayon_px: [4.5, 6], contour_largeur_px: 1.5, flou_px: 1 },
    { part: 0.25, vitesse_px_s: [46, 60], rayon_px: [6, 8], contour_largeur_px: 2, flou_px: 2 }
  ]
}

// Les lumières de la ville (nuit, et heure bleue à 40 %). Lampadaires : lumieres-nuit/lanternes.json
// s'il est publié, sinon lampadaires-bdtopo (positions procédurales le long des routes, IGN BD TOPO®).
// Chaque point VISIBLE (sol dégagé autour du pied) pose au sol une NAPPE large et douce et un CŒUR
// plus vif, et un point brillant en haut du mât. Les nappes s'additionnent (les voisines forment des
// rubans le long des rues) dans une carte de lumière, saturée en douceur (1 − e^(−gain × somme)).
// Là où elle tombe, la surface se déplace en Lab vers NUIT_CIBLES.rue/facade (a*/b*, plafond de L*) :
// la luminance locale (texture) reste hors de ce plafond, les blancs ne brûlent pas ; le cœur s'y
// ajoute en mélange « écran ».
// Tailles en pixels du niveau natif 8, proportionnelles au zoom ensuite.
const VUE_DEPUIS_LA_VERTICALE = 50 * Math.PI / 180 // inclinaison de la caméra des dalles (nancy-3d)
const APLATI = Math.cos(VUE_DEPUIS_LA_VERTICALE) // le sol vu en oblique : ellipse plus basse que large
export const LAMPADAIRES = {
  intensite: { nuit: 1, "heure-bleue": 0.4 }, // les autres moments : aucune lumière
  metre_px: Math.sin(VUE_DEPUIS_LA_VERTICALE) * 2.2626, // hauteur à l'écran d'un mètre de mât (niveau 8)
  sol_m_px: 2.2626,           // largeur à l'écran d'un mètre au sol (niveau 8)
  niveau_min: 4,              // en dessous, rien
  sur_toits: 0.12,            // part de la lumière du sol reçue par les toits : modeste, pour garder leur couleur (tuiles, ardoises)
  nappe: {
    // v7 : rayon et poids agrandis (repli, en l'absence de masque-routes sur R2) pour que les nappes
    // des lampadaires voisins se rejoignent en un ruban continu le long de la rue, jamais éteint entre
    // deux mâts, plutôt que des flaques rondes isolées.
    rayon_px: 56,             // au niveau 8, proportionnel au zoom…
    rayon_min_ecran_px: 12,   // …sans descendre sous 12 px à l'écran ; en dessous, la nappe s'éclaircit d'autant
    aplatissement: APLATI,
    poids: 0.5,               // apport d'une nappe à la carte de lumière (0-1, au centre)
    gain: 2.8,                // saturation douce de la somme
    doseTeinte: 1.8,           // v7b : dosage du virage de teinte (a*/b*) vers NUIT_CIBLES.rue (>1 : sature tôt)
    // Correctif place/gare (v7b) : lift ADDITIF de clarté (L*), en points L*, plafonné à la cible dans le
    // shader — PAS un mélange vers la cible (qui écrasait toute variation locale dès que w approchait 1
    // sur une large zone, d'où l'aplat plat sur la place Stanislas et le carrefour de la gare).
    gainL: 40
  },
  coeur: {
    couleur: "#FFE08A",
    rayon_px: 11,
    rayon_min_ecran_px: 3,
    aplatissement: APLATI,
    poids: 0.4,
    gain: 2.6,
    rayonnement: 0.55         // part du cœur ajoutée en mélange « écran »
  },
  feu: {
    couleur: "#FFF4DC",       // cœur presque blanc, halo chaud autour
    diametre_px: [2, 3],      // à l'écran : ne descend pas sous 2 px, ne dépasse pas 3 px (hors halo)
    halo_couleur: "#FFC46B",
    // v7 : halo réduit (la lumière de la rue vient maintenant de la nappe, voir NAPPE) ; seul le point
    // du mât reste très brillant.
    halo_rayon_px: 2,
    halo_opacite: 0.35,       // part de `opacite` gardée pour le halo (dessinerFeux) ; le point du mât garde `opacite`
    opacite: 0.95
  },
  // Les grandes places, foyers de la ville : un halo chaud, posé sur leur sol minéral seulement
  // (ni bâti ni feuillage), rayon en mètres au sol ; altitude du sol en mètres (sans elle, la
  // projection pose le point à 231 m, donc trop haut à l'écran).
  places: {
    poids: 0.65,
    gain: 2,
    liste: [
      { nom: "place Stanislas", lat: 48.69355, lon: 6.18325, rayon_m: 75, altitude_m: 206 },
      { nom: "place de la Carrière", lat: 48.69565, lon: 6.18225, rayon_m: 95, altitude_m: 206 },
      { nom: "place Carnot", lat: 48.69373, lon: 6.17738, rayon_m: 90, altitude_m: 207 }
    ]
  },
  // Les façades : pixels bâtis (masque-bati, ou volumes de la carte de propriété au niveau 8) dont le
  // sol se trouve JUSTE EN DESSOUS à l'écran, dans une bande de la hauteur d'une façade ; les toits
  // sont au-dessus. La lumière reçue au pied de la façade la réchauffe, de moins en moins vers le haut.
  // v7 : bande plus haute et décroissance plus douce (repli, en l'absence de masque-facades sur R2)
  // pour que la lumière crème monte sur toute la façade visible, pas seulement son pied.
  // v7b : bande à nouveau agrandie (avec la recherche du sol approfondie, voir ambiance.js) et dosage
  // renforcé — les mesures sur les recadrages montraient les étages hauts encore gris, faute d'y monter.
  facades: {
    hauteur_px: 60,           // hauteur de la bande, au niveau 8 (≈ 26,5 m, ~8 étages)
    rechauffement: 1.8,       // part de la lumière du pied reçue en bas de façade
    decroissance: 0.4,        // exposant : plus grand, la lumière monte moins haut
    doseTeinte: 1.6,          // v7b : dosage du virage de teinte (a*/b*) vers NUIT_CIBLES.facade
    gainL: 32                 // v7b : lift additif de clarté (L*), plafonné à la cible (voir NAPPE.gainL)
  },
  // Les fenêtres allumées : ≈ `part` des pixels de façade, en grappes par bâtiment (cellules fixées
  // au sol : stables, sans clignotement). Au niveau 8, une fenêtre fait `fenetre_px` dans une
  // cellule de `cellule_px` ; plus loin, un point d'un pixel d'écran.
  // v7 : grille plus dense et plus intense pour que la façade se lise « avec ses fenêtres », comme la
  // référence.
  fenetres: {
    part: 0.15,
    cellule_px: [3, 4],
    fenetre_px: [2, 2],
    grappe_px: 22,            // taille d'un « bâtiment » : même humeur (beaucoup ou peu de fenêtres allumées)
    ecart_grappes: 0.8,       // 0 : toutes pareilles ; 1 : de presque éteintes à presque toutes allumées
    couleur: "#FFD98C",
    intensite: 0.88,
    intensite_au_loin: 0.58   // sous le niveau 8 (un point par pixel d'écran), moins vives : sinon, du grain
  },
  // Correctif gare : les quais et murs de soutènement des voies sont classés bâti avec du sol dégagé
  // juste en dessous (le ballast, le quai) et reçoivent donc à tort des fenêtres. Faute de masque
  // dédié, un couloir (segment + demi-largeur, en mètres au sol) le long des voies de la gare de Nancy
  // coupe seulement le tirage des fenêtres (la chaleur de façade reste) dans cette zone.
  zone_sans_fenetres: {
    nom: "gare de Nancy",
    a: { lat: 48.6917, lon: 6.1656 },
    b: { lat: 48.6889, lon: 6.1780 },
    demi_largeur_m: 130
  }
}

// Mode automatique.
export const AUTO = {
  // Moment selon la hauteur du soleil à Nancy, en degrés.
  jour_au_dessus: 6,          // au-dessus : jour ; de 0 à 6 : heure dorée (matin et soir)
  crepuscule_au_dessus: -8,   // de −8 à 0 : aube le matin, heure bleue le soir ; en dessous : nuit
  // Saison selon le mois (heure de Nancy) ; les autres mois : printemps-été.
  mois_automne: [10, 11],
  mois_hiver: [12, 1, 2],
  // Météo réelle : Open-Meteo, sans clé. Codes WMO : pluie (bruine, pluie, verglas, averses, orages)
  // et neige (chute, grains, averses de neige) ; le reste, et tout échec : clair.
  meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=48.6937&longitude=6.1834&current=weather_code",
  meteo_cache_min: 30,
  meteo_delai_ms: 5000,
  codes_pluie: [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99],
  codes_neige: [71, 73, 75, 77, 85, 86]
}
