// Les lumières de la nuit. Format « nancy-3d/lumieres-nuit » (lanternes.json, lampadaires-bdtopo.json) :
//   points : [x, y, h, v] — pied en pixels de mosaïque du niveau 8, h indice dans `hauteurs` (m),
//   v = 1 si le sol se voit autour du pied (seuls ceux-là sont éclairés).
//
// Pour chaque dalle d'ambiance :
//   1. `carteDeLumiere` dessine une CARTE DE LUMIÈRE, un canal par source, additionnés sur du noir :
//      rouge = nappes des lampadaires, vert = leurs cœurs, bleu = halos des grandes places. Elle
//      déborde de la dalle vers le bas (DEBORD px) : le shader y lit la lumière reçue au pied des
//      façades du bas de la dalle. Le shader (diorama/ambiance) la colore et la pose sur l'image.
//   2. `dessinerFeux` pose ensuite le point brillant en haut de chaque mât.
//
// Indépendance des bords : une dalle dessine tous les points dont la lumière peut l'atteindre, y
// compris ceux dont le pied tombe sur une dalle voisine ; deux dalles voisines dessinent donc la
// même lumière, chacune sa part, sans raccord visible.
import { COTE } from "diorama/couches"
import { LAMPADAIRES } from "diorama/reglages"

const NIVEAU_MAX = 8
export const DEBORD = 40 // px de dalle sous la dalle, dans la carte de lumière (≥ LAMPADAIRES.facades.hauteur_px)

// Lit le fichier et l'indexe par dalle du niveau 8 : { cases: Map("X/Y" → Float32Array [x, y, feu]*),
// visibles, marge, places } (feu : hauteur du feu à l'écran, en px du niveau 8 ; marge : portée
// maximale ; places : [x, y, rayon] en px du niveau 8). `projection` (diorama_projection) situe les places.
export async function chargerLampadaires(url, projection = null) {
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
  const marge = Math.max(LAMPADAIRES.nappe.rayon_px, feuMax + f.halo_rayon_px) + 2
  const places = projection
    ? LAMPADAIRES.places.liste.map((p) => [...projection.pixel(p.lat, p.lon, p.altitude_m ?? projection.zRef), p.rayon_m * LAMPADAIRES.sol_m_px])
    : []
  return { cases, visibles, marge, places, calque: json.calque }
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

// Motifs dessinés une fois : un disque par canal de la carte de lumière (dégradé doux, presque
// gaussien), aplati au dessin ; le feu (cœur clair et petit halo chaud).
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
  const doux = ([r, v, b]) => [[0, 1], [0.25, 0.8], [0.5, 0.45], [0.75, 0.15], [1, 0]]
    .map(([t, a]) => [t, `rgba(${r}, ${v}, ${b}, ${a})`])
  const f = LAMPADAIRES.feu
  const transparent = (hex) => `${hex}00`
  return {
    nappe: disque(64, doux([255, 0, 0])),
    coeur: disque(32, doux([0, 255, 0])),
    place: disque(128, doux([0, 0, 255])),
    halo: disque(32, [[0, `${f.halo_couleur}E0`], [0.4, `${f.halo_couleur}60`], [1, transparent(f.halo_couleur)]]),
    feu: disque(16, [[0, f.couleur], [0.6, f.couleur], [1, transparent(f.couleur)]])
  }
}

// Géométrie d'une dalle : échelle, origine et côté en px du niveau 8.
function cadre(coords) {
  const s = 2 ** (coords.z - NIVEAU_MAX) // px de la dalle par px du niveau 8
  const cote8 = COTE / s
  return { s, cote8, ox: coords.x * cote8, oy: coords.y * cote8 }
}

// Rayon à l'écran d'un motif au sol, et poids corrigé : sous le rayon minimal, la tache garde sa taille
// à l'écran mais s'éclaircit comme si elle avait rétréci (même quantité de lumière par surface).
function tache(reglage, s) {
  const naturel = reglage.rayon_px * s
  const rx = Math.max(reglage.rayon_min_ecran_px, naturel)
  return { rx, ry: rx * reglage.aplatissement, poids: reglage.poids * (naturel / rx) ** 2 }
}

// La carte de lumière de la dalle `coords` : un canevas COTE × (COTE + DEBORD), ou null si rien
// n'éclaire la dalle.
export function carteDeLumiere(coords, index) {
  if (!index || coords.z < LAMPADAIRES.niveau_min) return null
  motifs ||= preparerMotifs()
  const { s, cote8, ox, oy } = cadre(coords)
  const nappe = tache(LAMPADAIRES.nappe, s), coeur = tache(LAMPADAIRES.coeur, s)
  const m = nappe.rx / s + 2, bas = DEBORD / s
  const points = [...dansLeRectangle(index, ox - m, oy - m, ox + cote8 + m, oy + cote8 + bas + m)]
  const places = index.places.filter(([x, y, r]) =>
    x + r > ox && x - r < ox + cote8 && y + r > oy && y - r < oy + cote8 + bas)
  if (!points.length && !places.length) return null
  const toile = document.createElement("canvas")
  toile.width = COTE
  toile.height = COTE + DEBORD
  const ctx = toile.getContext("2d")
  ctx.fillStyle = "#000"
  ctx.fillRect(0, 0, toile.width, toile.height)
  ctx.globalCompositeOperation = "lighter"
  for (const [motif, t] of [[motifs.nappe, nappe], [motifs.coeur, coeur]]) {
    ctx.globalAlpha = Math.min(1, t.poids)
    for (const [x, y] of points) {
      const px = (x - ox) * s, py = (y - oy) * s
      ctx.drawImage(motif, px - t.rx, py - t.ry, t.rx * 2, t.ry * 2)
    }
  }
  ctx.globalAlpha = LAMPADAIRES.places.poids
  for (const [x, y, r] of places) {
    const rx = r * s, ry = rx * LAMPADAIRES.nappe.aplatissement
    ctx.drawImage(motifs.place, (x - ox) * s - rx, (y - oy) * s - ry, rx * 2, ry * 2)
  }
  return toile
}

// Les feux en haut des mâts, sur la dalle déjà étalonnée ; `force` : 1 la nuit, moins à l'heure bleue.
export function dessinerFeux(ctx, coords, index, force) {
  if (!index || force <= 0 || coords.z < LAMPADAIRES.niveau_min) return 0
  motifs ||= preparerMotifs()
  const { s, cote8, ox, oy } = cadre(coords)
  const f = LAMPADAIRES.feu
  const coeur = Math.min(f.diametre_px[1], Math.max(f.diametre_px[0], 2.5 * Math.sqrt(s))) // px d'écran
  const halo = Math.max(coeur, f.halo_rayon_px * s)
  const m = Math.max(index.marge, index.marge - f.halo_rayon_px + halo / s)
  const points = [...dansLeRectangle(index, ox - m, oy - m, ox + cote8 + m, oy + cote8 + m)]
  if (!points.length) return 0
  ctx.save()
  ctx.globalCompositeOperation = "lighter"
  for (const [x, y, feu] of points) {
    const px = (x - ox) * s, py = (y - feu - oy) * s
    ctx.globalAlpha = f.opacite * force * 0.6
    ctx.drawImage(motifs.halo, px - halo, py - halo, halo * 2, halo * 2)
    ctx.globalAlpha = f.opacite * force
    ctx.drawImage(motifs.feu, px - coeur / 2, py - coeur / 2, coeur, coeur)
  }
  ctx.restore()
  return points.length
}
