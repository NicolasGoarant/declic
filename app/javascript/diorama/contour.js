// Les bords du diorama : la maquette s'arrête sur le contour de la Métropole du Grand Nancy, posée
// sur la table (fond de carte, --table-fond), avec une tranche de terre sous son bord bas et une
// ombre portée.
//
// Contour : public/data/contour-metropole-v1.geojson (API Découpage administratif, EPCI 245400676,
// Admin Express IGN, Licence Ouverte 2.0), simplifié à 256 points. Fichier statique : aucun appel
// réseau extérieur à l'exécution.
//
// Le découpage se fait dalle par dalle : une dalle hors du contour n'est pas demandée, une dalle
// entièrement dedans sort telle quelle, une dalle du bord reçoit un masque CSS (le contour flouté,
// en SVG, cadré sur la dalle). La dalle garde son repère de pixels à son niveau : Leaflet la déplace
// et la met à l'échelle avec son conteneur (zoom animé, pincement), le masque suit sans calcul.
// Le socle et l'ombre sont des polygones Leaflet dans un volet sous les dalles, pour la même raison.

export const URL_CONTOUR = "/data/contour-metropole-v1.geojson"
const COTE = 256
const NIVEAU_REPERE = 8
const FLOU = 4 // écart type du fondu, en px d'écran : transition d'une dizaine de pixels
const PORTEE = 3 * FLOU // au-delà, le masque vaut 0 ou 1

export async function chargerContour() {
  const reponse = await fetch(URL_CONTOUR)
  if (!reponse.ok) throw new Error(`contour HTTP ${reponse.status}`)
  const geojson = await reponse.json()
  const geometrie = geojson.features?.[0]?.geometry
  if (geometrie?.type !== "Polygon") throw new Error("contour : polygone attendu")
  return geometrie.coordinates[0] // anneau extérieur, [lon, lat]
}

// Segment [a, b] et rectangle [x0, y0, x1, y1] (Liang-Barsky).
function coupe([ax, ay], [bx, by], [x0, y0, x1, y1]) {
  let t0 = 0, t1 = 1
  const dx = bx - ax, dy = by - ay
  for (const [p, q] of [[-dx, ax - x0], [dx, x1 - ax], [-dy, ay - y0], [dy, y1 - ay]]) {
    if (p === 0) { if (q < 0) return false; continue }
    const r = q / p
    if (p < 0) { if (r > t1) return false; if (r > t0) t0 = r } else { if (r < t0) return false; if (r < t1) t1 = r }
  }
  return true
}

function dedans([x, y], anneau) {
  let d = false
  for (let i = 0, j = anneau.length - 1; i < anneau.length; j = i++) {
    const [xi, yi] = anneau[i], [xj, yj] = anneau[j]
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) d = !d
  }
  return d
}

// `anneau` : le contour [lon, lat] ; `projection` : diorama_projection. Rend le découpage des dalles,
// l'emprise du contour en pixels de mosaïque (niveau 8) et l'anneau en pixels, pour Leaflet.
export function creerDecoupe(anneau, projection) {
  const pixels = anneau.map(([lon, lat]) => projection.pixel(lat, lon))
  const xs = pixels.map((p) => p[0]), ys = pixels.map((p) => p[1])
  const emprise = [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)]
  const niveaux = new Map()

  // L'anneau à l'échelle d'un niveau, son tracé SVG et son emprise.
  function niveau(z) {
    if (!niveaux.has(z)) {
      const k = 2 ** (z - NIVEAU_REPERE)
      const points = pixels.map(([x, y]) => [x * k, y * k])
      const d = "M" + points.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join("L") + "Z"
      niveaux.set(z, { points, d, emprise: emprise.map((v) => v * k) })
    }
    return niveaux.get(z)
  }

  // "dehors", "dedans" ou "bord" (à moins de PORTEE px du contour).
  function etat({ x, y, z }) {
    const n = niveau(z)
    const r = [x * COTE - PORTEE, y * COTE - PORTEE, (x + 1) * COTE + PORTEE, (y + 1) * COTE + PORTEE]
    const [ex0, ey0, ex1, ey1] = n.emprise
    if (r[2] < ex0 || r[0] > ex1 || r[3] < ey0 || r[1] > ey1) return "dehors"
    for (let i = 0; i < n.points.length - 1; i++) if (coupe(n.points[i], n.points[i + 1], r)) return "bord"
    return dedans([(x + 0.5) * COTE, (y + 0.5) * COTE], n.points) ? "dedans" : "dehors"
  }

  // Masque d'une dalle du bord : le contour flouté, vu à travers la dalle.
  function masque({ x, y, z }) {
    const n = niveau(z), x0 = x * COTE, y0 = y * COTE
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${COTE}" height="${COTE}" viewBox="${x0} ${y0} ${COTE} ${COTE}">` +
      `<filter id="f" filterUnits="userSpaceOnUse" x="${x0 - PORTEE}" y="${y0 - PORTEE}" width="${COTE + 2 * PORTEE}" height="${COTE + 2 * PORTEE}">` +
      `<feGaussianBlur stdDeviation="${FLOU}"/></filter><path d="${n.d}" fill="#fff" filter="url(#f)"/></svg>`
    return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`
  }

  // Pose le masque sur les dalles du bord d'une couche (tous types de dalles : img, canvas).
  function decouper(couche) {
    couche.on("tileloadstart", ({ tile, coords }) => {
      if (etat(coords) !== "bord") return
      const m = masque(coords)
      for (const p of ["mask", "-webkit-mask"]) {
        tile.style.setProperty(`${p}-image`, m)
        tile.style.setProperty(`${p}-size`, `${COTE}px ${COTE}px`)
        tile.style.setProperty(`${p}-repeat`, "no-repeat")
      }
    })
    return couche
  }

  return { etat, decouper, emprise, pixels, contient: (px) => dedans(px, pixels) }
}

// Le socle (tranche de terre sous le bord bas) et l'ombre portée, dans un volet sous les dalles.
// Décalages et flou en CSS (.diorama-socle, .diorama-ombre), en px d'écran.
export function poserSocle(L, carte, pixels) {
  const volet = carte.createPane("socle")
  volet.style.zIndex = 150
  const rendu = L.svg({ pane: "socle", padding: 0.5 })
  const latlngs = pixels.map(([x, y]) => carte.unproject(L.point(x, y), NIVEAU_REPERE))
  const options = { renderer: rendu, interactive: false, stroke: false, fillOpacity: 1 }
  L.polygon(latlngs, { ...options, className: "diorama-ombre" }).addTo(carte)
  L.polygon(latlngs, { ...options, className: "diorama-socle" }).addTo(carte)
  // Le rendu SVG n'existe qu'une fois la carte dotée d'une vue (la mini-carte la reçoit après).
  carte.whenReady(() => {
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    defs.innerHTML = '<filter id="diorama-flou-ombre" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="7"/></filter>'
    rendu._container.prepend(defs)
  })
}
