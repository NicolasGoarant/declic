// Les MARQUAGES AU SOL que le style jeu-video-v2 a effacés (rues en aplat) : passages piétons, bandes et pistes cyclables,
// bordures de trottoir. Format « nancy-3d/marquages-sol » (nancy-3d rapports/declic-couches-v2 d02, relevés dans
// OpenStreetMap, publiés sur R2 : la page ne parle jamais à Overpass), en pixels de mosaïque du niveau 8.
//
// Ils sont peints UNE FOIS par dalle, dans la passe d'ambiance (diorama/ambiance), sur la dalle d'origine AVANT l'étalonnage :
// la nuit, la pluie, la neige les traitent comme le reste du sol. Jamais dans un calque animé. Seulement au niveau 8 et au-delà
// (MARQUAGES.niveau_min) : plus loin, un passage fait 2 px et coûterait quatre fois plus de tracés pour rien de lisible.
// La carte de propriété les borne au sol visible (classes 1 et 3) : un toit ou une couronne devant la rue les cache.
import { COTE } from "diorama/couches"
import { MARQUAGES } from "diorama/reglages"

const NIVEAU_REPERE = 8

// Lit le fichier et range chaque objet dans les dalles du niveau 8 qu'il touche (boîte élargie de 4 px).
export async function chargerMarquages(url) {
  const reponse = await fetch(url)
  if (!reponse.ok) throw new Error(`${url} : HTTP ${reponse.status}`)
  const json = await reponse.json()
  if (json.format !== "nancy-3d/marquages-sol") throw new Error(`${url} : format ${json.format}`)
  const cases = new Map()
  const ranger = (objet, x0, y0, x1, y1) => {
    for (let X = Math.floor((x0 - 4) / COTE); X <= Math.floor((x1 + 4) / COTE); X++) {
      for (let Y = Math.floor((y0 - 4) / COTE); Y <= Math.floor((y1 + 4) / COTE); Y++) {
        const cle = `${X}/${Y}`
        if (!cases.has(cle)) cases.set(cle, { passages: [], cyclables: [], bordures: [] })
        objet(cases.get(cle))
      }
    }
  }
  const boite = (l, debut) => {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    for (let i = debut; i < l.length; i += 2) {
      x0 = Math.min(x0, l[i]); x1 = Math.max(x1, l[i]); y0 = Math.min(y0, l[i + 1]); y1 = Math.max(y1, l[i + 1])
    }
    return [x0, y0, x1, y1]
  }
  for (const p of json.passages?.liste || []) {
    const r = p[6] * Math.hypot(p[4], p[5]) + 4
    ranger((c) => c.passages.push(p), p[0] - r, p[1] - r, p[0] + r, p[1] + r)
  }
  for (const l of json.cyclables?.liste || []) ranger((c) => c.cyclables.push(l), ...boite(l, 1))
  for (const l of json.bordures?.liste || []) ranger((c) => c.bordures.push(l), ...boite(l, 0))
  return { cases, longueur_m: json.passages?.longueur_m ?? 3 }
}

// Le sol visible de la dalle, en masque alpha (classes 1 et 3 de la carte de propriété, déjà à la taille de la dalle).
function masqueSol(classe) {
  const t = document.createElement("canvas")
  t.width = t.height = COTE
  const c = t.getContext("2d", { willReadFrequently: true })
  c.drawImage(classe, 0, 0, COTE, COTE)
  const img = c.getImageData(0, 0, COTE, COTE), p = img.data
  for (let i = 0; i < p.length; i += 4) {
    const k = p[i]
    p[i] = p[i + 1] = p[i + 2] = 255
    p[i + 3] = k === 1 || k === 3 ? 255 : 0
  }
  c.putImageData(img, 0, 0)
  return t
}

// La dalle `base` avec ses marquages, ou `base` telle quelle (rien à tracer, niveau trop large, pas de carte de propriété).
export function avecMarquages(base, coords, index, classe) {
  if (!index || !classe || coords.z < MARQUAGES.niveau_min) return base
  const s = 2 ** (coords.z - NIVEAU_REPERE)
  const cote8 = COTE / s, ox = coords.x * cote8, oy = coords.y * cote8
  // les objets des dalles n8 qui recouvrent celle-ci (une seule au niveau 8 et au-delà)
  const c = index.cases.get(`${Math.floor(ox / COTE)}/${Math.floor(oy / COTE)}`)
  if (!c) return base
  const toile = document.createElement("canvas")
  toile.width = toile.height = COTE
  const ctx = toile.getContext("2d")
  const m = MARQUAGES, metre = m.sol_m_px * s
  const tracer = (l, debut) => {
    ctx.beginPath()
    ctx.moveTo((l[debut] - ox) * s, (l[debut + 1] - oy) * s)
    for (let i = debut + 2; i < l.length; i += 2) ctx.lineTo((l[i] - ox) * s, (l[i + 1] - oy) * s)
    ctx.stroke()
  }
  ctx.lineCap = "round"
  ctx.lineJoin = "round"
  // bordures : un trait clair fin
  ctx.strokeStyle = m.bordures.couleur
  ctx.globalAlpha = m.bordures.opacite
  ctx.lineWidth = Math.max(m.bordures.largeur_min_px, m.bordures.largeur_m * metre)
  for (const l of c.bordures) tracer(l, 0)
  // voies cyclables : bande verte (peinte) ou piste plus large
  for (const l of c.cyclables) {
    const v = l[0] === 1 ? m.cyclables.piste : m.cyclables.bande
    ctx.strokeStyle = v.couleur
    ctx.globalAlpha = v.opacite
    ctx.lineWidth = Math.max(1, v.largeur_m * metre)
    tracer(l, 1)
  }
  // passages piétons : bandes blanches parallèles à la route, réparties en travers de la chaussée
  ctx.fillStyle = m.passages.couleur
  ctx.globalAlpha = m.passages.opacite
  const pas = m.passages.pas_m, bande = m.passages.bande_m, demiLong = index.longueur_m / 2
  for (const [x, y, ax, ay, tx, ty, demi] of c.passages) {
    const cx = (x - ox) * s, cy = (y - oy) * s
    for (let k = -demi + pas / 2; k < demi; k += pas) {
      // quadrilatère : le long de la route ±demiLong, en travers de k à k + bande (projection affine : un parallélogramme)
      const q = [[-demiLong, k], [demiLong, k], [demiLong, k + bande], [-demiLong, k + bande]]
        .map(([a, t]) => [cx + (a * ax + t * tx) * s, cy + (a * ay + t * ty) * s])
      ctx.beginPath()
      ctx.moveTo(...q[0]); ctx.lineTo(...q[1]); ctx.lineTo(...q[2]); ctx.lineTo(...q[3])
      ctx.fill()
    }
  }
  // borné au sol visible
  ctx.globalAlpha = 1
  ctx.globalCompositeOperation = "destination-in"
  ctx.drawImage(masqueSol(classe), 0, 0)
  // posé sur la dalle
  const sortie = document.createElement("canvas")
  sortie.width = sortie.height = COTE
  const so = sortie.getContext("2d")
  so.drawImage(base, 0, 0, COTE, COTE)
  so.drawImage(toile, 0, 0)
  return sortie
}
