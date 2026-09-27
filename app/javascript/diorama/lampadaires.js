// Les lampadaires de la nuit : une flaque de lumière chaude au sol et un point brillant en haut du
// mât, dessinés sur chaque dalle d'ambiance après l'étalonnage (mélange additif), puis mis en cache
// avec elle. Format « nancy-3d/lumieres-nuit » (lanternes.json, lampadaires-bdtopo.json) :
//   points : [x, y, h, v] — pied en pixels de mosaïque du niveau 8, h indice dans `hauteurs` (m),
//   v = 1 si le sol se voit autour du pied (seuls ceux-là sont éclairés).
//
// Indépendance des bords : une dalle dessine tous les points dont la flaque ou le feu peut
// l'atteindre, y compris ceux dont le pied tombe sur une dalle voisine ; deux dalles voisines
// dessinent donc la même lumière, chacune sa moitié, sans raccord visible.
import { COTE } from "diorama/couches"
import { LAMPADAIRES } from "diorama/reglages"

const NIVEAU_MAX = 8

// Lit le fichier et l'indexe par dalle du niveau 8 : { cases: Map("X/Y" → Float32Array [x, y, feu]*),
// visibles, marge } (feu : hauteur du feu à l'écran, en px du niveau 8 ; marge : portée maximale).
export async function chargerLampadaires(url) {
  const reponse = await fetch(url)
  if (!reponse.ok) throw new Error(`${url} : HTTP ${reponse.status}`)
  const json = await reponse.json()
  if (json.format !== "nancy-3d/lumieres-nuit" || !Array.isArray(json.points)) throw new Error(`${url} : format ${json.format}`)
  const hauteurs = json.hauteurs || [8]
  const listes = new Map()
  let visibles = 0, feuMax = 0
  for (const [x, y, h, v] of json.points) {
    if (v !== 1) continue
    const feu = (hauteurs[h] ?? hauteurs[0]) * LAMPADAIRES.metre_px
    const cle = `${Math.floor(x / COTE)}/${Math.floor(y / COTE)}`
    if (!listes.has(cle)) listes.set(cle, [])
    listes.get(cle).push(x + 0.5, y + 0.5, feu) // centre du pixel
    visibles++
    if (feu > feuMax) feuMax = feu
  }
  const cases = new Map([...listes].map(([cle, l]) => [cle, Float32Array.from(l)]))
  const f = LAMPADAIRES.feu
  const marge = Math.max(LAMPADAIRES.flaque.rayon_px, feuMax + f.halo_rayon_px) + 2
  return { cases, visibles, marge, calque: json.calque }
}

// Les points visibles dont le pied est dans le rectangle [x0, y0, x1, y1] (px du niveau 8).
function* dansLeRectangle(index, x0, y0, x1, y1) {
  for (let X = Math.floor(x0 / COTE); X <= Math.floor(x1 / COTE); X++) {
    for (let Y = Math.floor(y0 / COTE); Y <= Math.floor(y1 / COTE); Y++) {
      const l = index.cases.get(`${X}/${Y}`)
      if (!l) continue
      for (let i = 0; i < l.length; i += 3) {
        const x = l[i], y = l[i + 1]
        if (x >= x0 && x < x1 && y >= y0 && y < y1) yield [x, y, l[i + 2]]
      }
    }
  }
}

// Nombre de lampadaires éclairés dont le pied est dans le rectangle (px du niveau 8).
export function compterLampadaires(index, x0, y0, x1, y1) {
  let n = 0
  for (const _ of dansLeRectangle(index, x0, y0, x1, y1)) n++
  return n
}

// Motifs dessinés une fois : la flaque (dégradé radial, disque de rayon 64 px, aplati au dessin)
// et le feu (cœur clair et petit halo chaud).
let motifs = null
function preparerMotifs() {
  const disque = (rayon, arrets) => {
    const c = document.createElement("canvas")
    c.width = c.height = rayon * 2
    const cx = c.getContext("2d")
    const g = cx.createRadialGradient(rayon, rayon, 0, rayon, rayon, rayon)
    for (const [t, couleur] of arrets) g.addColorStop(t, couleur)
    cx.fillStyle = g
    cx.fillRect(0, 0, c.width, c.height)
    return c
  }
  const fl = LAMPADAIRES.flaque, f = LAMPADAIRES.feu
  const transparent = (hex) => `${hex}00`
  return {
    flaque: disque(64, [[0, fl.couleur], [0.35, `${fl.couleur}B0`], [1, transparent(fl.couleur)]]),
    halo: disque(32, [[0, `${f.halo_couleur}E0`], [0.4, `${f.halo_couleur}60`], [1, transparent(f.halo_couleur)]]),
    coeur: disque(16, [[0, f.couleur], [0.6, f.couleur], [1, transparent(f.couleur)]])
  }
}

// Dessine les lumières de la dalle `coords` sur son canevas 2D ; `force` : 1 la nuit, 0,5 à l'heure bleue.
export function dessinerLampadaires(ctx, coords, index, force) {
  if (!index || force <= 0 || coords.z < LAMPADAIRES.niveau_min) return 0
  motifs ||= preparerMotifs()
  const s = 2 ** (coords.z - NIVEAU_MAX) // px de la dalle par px du niveau 8
  const cote8 = COTE / s
  const ox = coords.x * cote8, oy = coords.y * cote8
  const fl = LAMPADAIRES.flaque, f = LAMPADAIRES.feu
  const rx = Math.max(fl.rayon_min_ecran_px, fl.rayon_px * s), ry = rx * fl.aplatissement
  const coeur = Math.min(f.diametre_px[1], Math.max(f.diametre_px[0], 2.5 * Math.sqrt(s))) // px d'écran
  const halo = Math.max(coeur, f.halo_rayon_px * s)
  // Aux petits niveaux, flaque et feu gardent une taille minimale à l'écran : la portée grandit d'autant.
  const m = Math.max(index.marge, index.marge - f.halo_rayon_px + halo / s, rx / s + 2)
  const points = [...dansLeRectangle(index, ox - m, oy - m, ox + cote8 + m, oy + cote8 + m)]
  if (!points.length) return 0
  ctx.save()
  ctx.globalCompositeOperation = "lighter"
  ctx.globalAlpha = fl.opacite * force
  for (const [x, y] of points) {
    const px = (x - ox) * s, py = (y - oy) * s
    ctx.drawImage(motifs.flaque, px - rx, py - ry, rx * 2, ry * 2)
  }
  for (const [x, y, feu] of points) {
    const px = (x - ox) * s, py = (y - feu - oy) * s
    ctx.globalAlpha = f.opacite * force * 0.6
    ctx.drawImage(motifs.halo, px - halo, py - halo, halo * 2, halo * 2)
    ctx.globalAlpha = f.opacite * force
    ctx.drawImage(motifs.coeur, px - coeur / 2, py - coeur / 2, coeur, coeur)
  }
  ctx.restore()
  return points.length
}
