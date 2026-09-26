// Les couches de fond du diorama, portées de maquette-declic-v3 (nancy-3d).
//
// Le manifeste du lot liste les dalles publiées niveau par niveau : une dalle absente y est
// « entièrement transparente » et répond 404. On ne demande donc que les dalles listées ; les
// autres sont posées vides, sans requête, et la console reste propre.

export const COTE = 256

function tuileVide(fini) {
  const vide = document.createElement("div")
  setTimeout(() => fini(null, vide), 0)
  return vide
}

// Le « Vrai Nancy » : les dalles WebP du lot, telles quelles.
export function creerCoucheDalles(L, { modele, estListee, options }) {
  const Couche = L.TileLayer.extend({
    createTile(coords, fini) {
      if (!estListee(coords)) return tuileVide(fini)
      return L.TileLayer.prototype.createTile.call(this, coords, fini)
    }
  })
  return new Couche(modele, { ...options, crossOrigin: "anonymous" })
}

// Les dalles recalculées (maquette blanche, ambiance) : calculées une fois, puis recopiées depuis ce
// cache quand Leaflet les redemande (retour sur une zone, zoom arrière puis avant). Le canevas de la
// dalle est gardé tel quel : Leaflet ne réutilise pas ses tuiles. Les plus anciennes sortent au-delà
// de `max` (≈ 256 Kio chacune).
export function creerCache(max = 160) {
  const dalles = new Map()
  return {
    // Recopie la dalle gardée dans `toile` ; false si elle n'a pas encore été calculée.
    lire(chemin, toile) {
      const gardee = dalles.get(chemin)
      if (!gardee) return false
      dalles.delete(chemin)
      dalles.set(chemin, gardee) // la plus récemment servie passe en dernier
      toile.getContext("2d", { willReadFrequently: true }).drawImage(gardee, 0, 0)
      return true
    },
    garder(chemin, toile) {
      dalles.set(chemin, toile)
      if (dalles.size > max) dalles.delete(dalles.keys().next().value)
    }
  }
}

function charger(url) {
  return new Promise((ok) => {
    const image = new Image()
    image.crossOrigin = "anonymous"
    image.onload = () => ok(image)
    image.onerror = () => ok(null)
    image.src = url
  })
}

// La « Maquette blanche » : un grade au-dessus des dalles, jamais un nouveau rendu. Le masque
// du bâti (un octet par pixel, 0 = pas de bâti, 255 = entièrement bâti) ne couvre que le
// centre-ville aux niveaux 6 à 8 ; ailleurs la dalle sort telle quelle.
const DESAT = 0.85 // vers le gris, part du chemin
const CLAIR = 0.55 // puis vers le blanc

export function creerCoucheBlanche(L, { dalle, masque, estListee, masqueListe, options }) {
  const cache = creerCache()
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      if (!estListee(coords)) return tuileVide(fini)
      const toile = document.createElement("canvas")
      toile.width = COTE
      toile.height = COTE
      const chemin = `${coords.z}/${coords.x}/${coords.y}`
      if (cache.lire(chemin, toile)) { setTimeout(() => fini(null, toile), 0); return toile }
      const urlMasque = masqueListe(coords) ? masque(chemin) : null
      Promise.all([charger(dalle(chemin)), urlMasque ? charger(urlMasque) : null]).then(([fond, couverture]) => {
        if (!fond) { fini(new Error("dalle absente"), toile); return }
        const ctx = toile.getContext("2d", { willReadFrequently: true })
        ctx.drawImage(fond, 0, 0, COTE, COTE)
        if (couverture) blanchir(ctx, couverture)
        cache.garder(chemin, toile)
        fini(null, toile)
      })
      return toile
    }
  })
  return new Couche(options)
}

function blanchir(ctx, couverture) {
  const mt = document.createElement("canvas")
  mt.width = mt.height = COTE
  const mx = mt.getContext("2d", { willReadFrequently: true })
  mx.drawImage(couverture, 0, 0, COTE, COTE)
  const q = mx.getImageData(0, 0, COTE, COTE).data
  const d = ctx.getImageData(0, 0, COTE, COTE)
  const p = d.data
  for (let i = 0; i < p.length; i += 4) {
    const w = q[i] / 255
    if (w === 0) continue
    const l = 0.2126 * p[i] + 0.7152 * p[i + 1] + 0.0722 * p[i + 2]
    for (let k = 0; k < 3; k++) {
      let c = p[i + k] + (l - p[i + k]) * DESAT
      c = c + (255 - c) * CLAIR
      p[i + k] = p[i + k] + (c - p[i + k]) * w // pondéré par la couverture
    }
  }
  ctx.putImageData(d, 0, 0)
}
