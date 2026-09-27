// Les bouquets : les pins dont les pieds sont à moins de SEUIL_BOUQUET_PX les uns des autres à
// l'écran partagent un seul pied, et leurs tiges partent de ce pied en éventail. Remplace
// Leaflet.markercluster et ses cercles numérotés. Le regroupement se recalcule à chaque fin de zoom.
//
// Tailles et éventail : toutes les valeurs viennent de diorama/reglages.js#PINS.
import { PINS } from "diorama/reglages"

export const SEUIL_BOUQUET_PX = 28
export const FLEURS_MAX = 6

// Hachage déterministe (FNV-1a, 32 bits) : la même graine (l'identifiant du point, ex. "o42") donne
// toujours le même résultat, d'une visite ou d'un redessin à l'autre — contrairement à Math.random(),
// qui désynchroniserait la respiration de chaque pin à chaque zoom.
function hachage(graine) {
  let h = 0x811c9dc5
  for (let i = 0; i < graine.length; i++) {
    h ^= graine.charCodeAt(i)
    h = Math.imul(h, 0x01000193)
  }
  return h >>> 0
}

// Période (dans PINS.respiration) et retard (négatif : la boucle démarre en cours de route) de la
// respiration d'un pin, tirés de son identifiant.
export function respiration(id) {
  const h = hachage(String(id))
  const { periode_min_s: min, periode_max_s: max } = PINS.respiration
  const periode = min + ((h % 10000) / 10000) * (max - min)
  const retard = -((Math.floor(h / 10000) % 10000) / 10000) * periode
  return { periode, retard }
}

// L'échelle à l'affichage pour que l'encre (les pixels non transparents du PNG) fasse la même
// hauteur visible quelle que soit la catégorie (voir PINS.fraction_utile).
export function echelleIcone(cle) {
  return 1 / (PINS.fraction_utile[cle] ?? 1)
}

// Dimensions du pin (avant l'échelle par catégorie), pour la géométrie Leaflet (iconSize, iconAnchor) :
// dépendent de la largeur d'écran (PINS.hauteur_px), pas du zoom.
export function dispositionPin(etroit) {
  const icone = etroit ? PINS.hauteur_px.etroit : PINS.hauteur_px.large
  const pied = icone + PINS.tige_longueur_px - PINS.recouvrement_px
  return { icone, pied, hauteur: Math.ceil(pied + PINS.socle.hauteur_px / 2 + 1) }
}

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

// Éventail de n tiges, toutes de la longueur des pins isolés (PINS.tige_longueur_px) : le demi-angle
// s'élargit avec n (PINS.eventail) pour que les fleurs ne se chevauchent pas malgré la tige commune.
// x, y : bout de la tige depuis le pied, en px (y négatif vers le haut).
export function eventail(n) {
  const longueur = PINS.tige_longueur_px
  if (n === 1) return [{ angle: 0, longueur, x: 0, y: -longueur }]
  const { demi_angle_base, demi_angle_pas, demi_angle_max } = PINS.eventail
  const demiAngle = Math.min(demi_angle_max, demi_angle_base + demi_angle_pas * (n - 1))
  return Array.from({ length: n }, (_, i) => {
    const angle = -demiAngle + (2 * demiAngle * i) / (n - 1)
    const a = (angle * Math.PI) / 180
    return { angle, longueur, x: Math.sin(a) * longueur, y: -Math.cos(a) * longueur }
  })
}
