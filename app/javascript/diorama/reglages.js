// LES RÉGLAGES DES AMBIANCES, en un seul endroit : c'est ici qu'on retouche les étalonnages.
//
// Trois réglages indépendants se cumulent sur chaque dalle, dans cet ordre :
//   1. la SAISON (hiver, automne) teinte le paysage ;
//   2. la MÉTÉO (pluie, neige) mouille le sol ou blanchit les toits, et fait tomber des particules ;
//   3. le MOMENT (aube, heure dorée, heure bleue, nuit) éclaire le tout, puis la nuit allume ses lumières.
// Heure bleue et hiver reprennent les étalonnages publiés sur R2 (ambiances/{nom}-actuelle.json) ;
// aube, heure dorée et nuit sont des étalonnages paramétriques, définis ci-dessous.

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
  // La ville reste lisible : on assombrit franchement, mais on relève un peu les noirs (voile bleu nuit).
  nuit: {
    temperature: 12500, teinte: -0.04, saturation: 0.5, contraste: 0.92, luminosite: 0.5,
    voile: { couleur: [22, 34, 72], part: 0.16 }
  }
}

// Heure bleue et hiver : étalonnages publiés, dosés par `force` (1 = tel quel).
export const PUBLIES = { "heure-bleue": { force: 1 }, hiver: { force: 1 } }

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
  couleur: "rgba(90, 110, 140, 0.55)",
  lisere_couleur: "rgba(225, 235, 248, 0.55)", // filet clair d'un côté du trait
  lisere_decalage_px: 1,
  plans: [
    { part: 0.45, vitesse_px_s: [700, 780], longueur_px: [28, 34], epaisseur_px: 2, flou_px: 0 },
    { part: 0.35, vitesse_px_s: [780, 900], longueur_px: [34, 41], epaisseur_px: 2.5, flou_px: 0.5 },
    { part: 0.20, vitesse_px_s: [900, 1050], longueur_px: [41, 48], epaisseur_px: 3, flou_px: 1 }
  ]
}

export const NEIGE = {
  toits: 0.82,                // blanchiment maximal des toits (masque-bati), progressif selon la pente et le bruit
  sol: 0.14,                  // voile de neige sur le reste
  couleur: [238, 243, 250],
  particules_1920: 120,       // à 1920 × 1080 ; proportionnel à la surface réelle ensuite
  couleur_flocon: "rgba(255, 255, 255, 0.9)",
  contour_couleur: "rgba(60, 70, 90, 0.35)", // contour doux, pour rester visible sur la maquette claire
  derive_px: 15,               // amplitude du balancement horizontal (variation ×0,7 à ×1,3 par flocon)
  plans: [
    { part: 0.40, vitesse_px_s: [26, 34], rayon_px: [3.5, 4.5], contour_largeur_px: 1, flou_px: 0 },
    { part: 0.35, vitesse_px_s: [34, 46], rayon_px: [4.5, 6], contour_largeur_px: 1.5, flou_px: 1 },
    { part: 0.25, vitesse_px_s: [46, 60], rayon_px: [6, 8], contour_largeur_px: 2, flou_px: 2 }
  ]
}

// La nuit, si la couche lumieres-nuit est publiée (R, lanternes ; V, fenêtres possibles) :
// halos chauds autour des lanternes, et une part des fenêtres allumées au hasard (graine fixe par dalle).
export const LUMIERES = {
  halo_couleur: [255, 186, 104], halo_rayon_px: 9, halo_force: 0.9,
  fenetre_couleur: [255, 214, 140], fenetres_allumees: 0.22
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
