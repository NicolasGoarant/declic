// Les bouquets : les pins dont les pieds sont à moins de SEUIL_BOUQUET_PX les uns des autres à
// l'écran partagent un seul pied, et leurs tiges partent de ce pied en éventail. Remplace
// Leaflet.markercluster et ses cercles numérotés. Le regroupement se recalcule à chaque fin de zoom.

export const SEUIL_BOUQUET_PX = 28
export const FLEURS_MAX = 6

// elements : [{ x, y, … }] en pixels du zoom courant → groupes d'éléments (liaison simple : A près
// de B et B près de C, les trois ensemble). Grille de la taille du seuil : seules les cases voisines
// sont comparées.
export function regrouper(elements, seuil = SEUIL_BOUQUET_PX) {
  const parent = elements.map((_, i) => i)
  const racine = (i) => {
    while (parent[i] !== i) { parent[i] = parent[parent[i]]; i = parent[i] }
    return i
  }
  const grille = new Map()
  elements.forEach((e, i) => {
    const cx = Math.floor(e.x / seuil), cy = Math.floor(e.y / seuil)
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        for (const j of grille.get(`${cx + dx}/${cy + dy}`) || []) {
          if (Math.hypot(e.x - elements[j].x, e.y - elements[j].y) < seuil) parent[racine(i)] = racine(j)
        }
      }
    }
    const cle = `${cx}/${cy}`
    if (!grille.has(cle)) grille.set(cle, [])
    grille.get(cle).push(i)
  })
  const groupes = new Map()
  elements.forEach((e, i) => {
    const r = racine(i)
    if (!groupes.has(r)) groupes.set(r, [])
    groupes.get(r).push(e)
  })
  return [...groupes.values()]
}

// Éventail de n tiges : angles répartis entre -45° et +45°, longueurs alternées (courte, longue)
// pour que deux fleurs voisines ne soient pas à la même hauteur. x, y : bout de la tige depuis le
// pied, en px (y négatif vers le haut).
export function eventail(n) {
  return Array.from({ length: n }, (_, i) => {
    const angle = n === 1 ? 0 : -45 + (90 * i) / (n - 1)
    const longueur = 50 + (i % 2) * 32 + (i % 3) * 3
    const a = (angle * Math.PI) / 180
    return { angle, longueur, x: Math.sin(a) * longueur, y: -Math.cos(a) * longueur }
  })
}
