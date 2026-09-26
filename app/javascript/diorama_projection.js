// Projection géographique → pixel de la mosaïque diorama (toits-v1).
//
// Portage de la chaîne de ~/Documents/nancy-3d/projection.js (Camera.pixelL93 +
// Camera.projeterMosaique), réduite à ce qu'il faut pour poser un marqueur, sans
// dépendance. Les paramètres viennent du manifeste (`reference_de_pose`).
//
// L'azimut est un relèvement dans la GRILLE Lambert-93 : on convertit donc en
// EPSG:2154 avant de projeter, ce qui porte déjà la convergence des méridiens
// (−2,31° à Nancy). Ne rien corriger ensuite.
//
// LIMITATION ALTITUDE : le manifeste ne contient pas de modèle de surface (MNS).
// Sans altitude fournie, on prend z = z_ref (231,17 m, altitude de référence de
// la vue). Un point réellement plus bas que z_ref sera posé trop haut à l'écran
// d'environ (z_ref − z) × facteur_hauteur × échelle ≈ 1,73 px de mosaïque par
// mètre d'écart (à pleine résolution, niveau 8). Le centre de Nancy étant vers
// 205-215 m, compter ~30-45 px de décalage vertical en ville basse, davantage
// sur les hauteurs (plateau de Brabois, Haye) — dans l'autre sens sur les points
// plus hauts que z_ref. Passer `z` à la main pour corriger un point connu.

// Origine de la pose de la référence dans la mosaïque (manifeste : « origine »).
const ORIGINE_MOSAIQUE_PX = [11287, 8634];

// WGS84 → Lambert-93 (EPSG:2154), conique conforme, GRS80.
const A = 6378137.0, E = 0.0818191910428158;
const LON0 = 3.0 * Math.PI / 180.0;
const N = 0.7256077650, C = 11754255.426;
const XS = 700000.0, YS = 12655612.05;

const isometrique = (phi) => {
  const s = E * Math.sin(phi);
  return Math.log(Math.tan(Math.PI / 4 + phi / 2) * Math.pow((1 - s) / (1 + s), E / 2));
};

export function versL93(lon, lat) {
  if (!isFinite(lon) || !isFinite(lat)) throw new Error(`versL93 : coordonnée non finie (${lon}, ${lat})`);
  const phi = lat * Math.PI / 180.0, lambda = lon * Math.PI / 180.0;
  const R = C * Math.exp(-N * isometrique(phi));
  const gamma = N * (lambda - LON0);
  return [XS + R * Math.sin(gamma), YS - R * Math.cos(gamma)];
}

// Lambert-93 (EPSG:2154) → WGS84 : inverse de versL93. Renvoie [lon, lat] en degrés.
export function depuisL93(x, y) {
  const dx = x - XS, dy = YS - y;
  const R = Math.hypot(dx, dy);
  const lon = (LON0 + Math.atan2(dx, dy) / N) * 180.0 / Math.PI;
  const L = -Math.log(R / C) / N;
  let phi = 2 * Math.atan(Math.exp(L)) - Math.PI / 2;
  for (let i = 0; i < 8; i++) {
    const s = E * Math.sin(phi);
    phi = 2 * Math.atan(Math.exp(L) * Math.pow((1 + s) / (1 - s), E / 2)) - Math.PI / 2;
  }
  return [lon, phi * 180.0 / Math.PI];
}

// Construit le projecteur depuis le manifeste (objet JSON déjà chargé).
export function creerProjection(manifeste) {
  const r = manifeste.reference_de_pose;
  const a = r.azimut_deg * Math.PI / 180.0;
  const versOeil = [Math.sin(a), Math.cos(a)];
  const droite = [-Math.cos(a), Math.sin(a)];
  const [cx, cy] = r.centre_l93;
  const { z_ref: zRef, compression, facteur_hauteur: facteurHauteur,
          echelle_px_par_m: echelle, marge_px: marge, umin, hmax } = r;

  // Lambert-93 (x, y) + altitude z → pixel de la mosaïque, niveau max (z=8).
  function pixelL93(x, y, z = zRef) {
    const dx = x - cx, dy = y - cy;
    const u = dx * droite[0] + dy * droite[1];
    const v = -(dx * versOeil[0] + dy * versOeil[1]);
    const h = v * compression + (z - zRef) * facteurHauteur;
    return [marge + (u - umin) * echelle + ORIGINE_MOSAIQUE_PX[0],
            marge + (hmax - h) * echelle + ORIGINE_MOSAIQUE_PX[1]];
  }

  // WGS84 (lat, lon) + altitude z (m, défaut z_ref) → pixel de la mosaïque.
  function pixel(lat, lon, z = zRef) {
    const [x, y] = versL93(lon, lat);
    return pixelL93(x, y, z);
  }

  // Pixel de la mosaïque → WGS84 [lon, lat], au sol (z = z_ref) : inverse de `pixel`, pour le réglage de la vue.
  function versWGS84(px, py) {
    const u = (px - marge - ORIGINE_MOSAIQUE_PX[0]) / echelle + umin;
    const h = hmax - (py - marge - ORIGINE_MOSAIQUE_PX[1]) / echelle;
    const v = -(h / compression);
    return depuisL93(cx + u * droite[0] - v * versOeil[0], cy + u * droite[1] - v * versOeil[1]);
  }

  const dansLaMosaique = ([px, py]) =>
    px >= 0 && py >= 0 && px < manifeste.taille_mosaique_px[0] && py < manifeste.taille_mosaique_px[1];

  return { pixel, pixelL93, versL93, versWGS84, dansLaMosaique, zRef, pxParMetreAltitude: facteurHauteur * echelle };
}
