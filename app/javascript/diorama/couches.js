// Les couches de fond du diorama, portées de maquette-declic-v3 (nancy-3d).
//
// Le manifeste du lot liste les dalles publiées niveau par niveau : une dalle absente y est
// « entièrement transparente » et répond 404. On ne demande donc que les dalles listées ; les
// autres sont posées vides, sans requête, et la console reste propre.

export const COTE = 256

// Les couches annexes (carte de propriété, masques du bâti et des arbres) s'arrêtent au niveau 8 ;
// un style peut aller plus loin (niveau_max de son manifeste). Plus près, une dalle annexe se tire
// de son ancêtre au niveau 8 : la part qu'elle en couvre, agrandie au plus proche voisin (des
// classes et des masques : un lissage inventerait des valeurs intermédiaires).
export const NIVEAU_ANNEXES = 8

// La dalle annexe d'origine de `coords` : { x, y, z, chemin } et sa part (sx, sy, cote) en px.
export function versAnnexe(coords) {
  const d = Math.max(0, coords.z - NIVEAU_ANNEXES), k = 2 ** d
  const x = Math.floor(coords.x / k), y = Math.floor(coords.y / k), z = coords.z - d
  return { x, y, z, chemin: `${z}/${x}/${y}`, sx: (coords.x - x * k) * COTE / k, sy: (coords.y - y * k) * COTE / k, cote: COTE / k }
}

// L'image annexe de `annexe` (versAnnexe), agrandie à la dalle si besoin ; null si absente.
export function chargerAnnexe(url, annexe) {
  return charger(url).then((image) => {
    if (!image || annexe.cote === COTE) return image
    const toile = document.createElement("canvas")
    toile.width = toile.height = COTE
    const ctx = toile.getContext("2d")
    ctx.imageSmoothingEnabled = false
    ctx.drawImage(image, annexe.sx, annexe.sy, annexe.cote, annexe.cote, 0, 0, COTE, COTE)
    return toile
  })
}

// Un canevas est toujours son propre calque GPU ; sur un écran au rapport de pixels non entier
// (125 %, 150 %…, très courant sur les portables), Chrome arrondit indépendamment la position de
// chaque calque au pixel physique le plus proche, ce qui laisse parfois un interstice sous-pixel
// entre deux dalles voisines (le fond clair de la table s'y voit). Les dalles image simples
// (creerCoucheDalles, sans canevas) n'ont pas ce défaut : Chrome les compose ensemble sans arrondi
// indépendant. Correctif : un recouvrement d'un pixel CSS sur le bord bas et droit de chaque dalle
// recalculée, imperceptible, qui comble l'interstice quel que soit le sens de l'arrondi.
export function comblerInterstices(couche) {
  couche.on("tileloadstart", ({ tile }) => {
    tile.style.width = `${COTE + 1}px`
    tile.style.height = `${COTE + 1}px`
  })
  return couche
}

function tuileVide(fini) {
  const vide = document.createElement("div")
  setTimeout(() => fini(null, vide), 0)
  return vide
}

// Le « Vrai Nancy » : les dalles WebP du lot, telles quelles. `dalle(coords)` choisit son URL (le
// style actif, ou son repli s'il ne couvre pas encore ce niveau) : pas de gabarit fixe.
export function creerCoucheDalles(L, { dalle, estCouverte, options }) {
  const Couche = L.TileLayer.extend({
    getTileUrl(coords) { return dalle(coords) },
    createTile(coords, fini) {
      if (!estCouverte(coords)) return tuileVide(fini)
      return L.TileLayer.prototype.createTile.call(this, coords, fini)
    }
  })
  return new Couche("", { ...options, crossOrigin: "anonymous" })
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
      toile.getContext("2d").drawImage(gardee, 0, 0)
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
    if (!url) { ok(null); return }
    const image = new Image()
    image.crossOrigin = "anonymous"
    image.onload = () => ok(image)
    image.onerror = () => ok(null)
    image.src = url
  })
}

// La « Maquette blanche » : un grade au-dessus des dalles, jamais un nouveau rendu. Le masque
// du bâti (un octet par pixel, 0 = pas de bâti, 255 = entièrement bâti) ne couvre que le
// centre-ville aux niveaux 6 à 8 (agrandi au-delà) ; ailleurs la dalle sort telle quelle.
const DESAT = 0.85 // vers le gris, part du chemin
const CLAIR = 0.55 // puis vers le blanc

export function creerCoucheBlanche(L, { dalle, masque, estCouverte, masqueListe, options }) {
  const cache = creerCache()
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      if (!estCouverte(coords)) return tuileVide(fini)
      const toile = document.createElement("canvas")
      toile.width = COTE
      toile.height = COTE
      const chemin = `${coords.z}/${coords.x}/${coords.y}`
      if (cache.lire(chemin, toile)) { setTimeout(() => fini(null, toile), 0); return toile }
      const annexe = versAnnexe(coords)
      const urlMasque = masqueListe(annexe) ? masque(annexe.chemin) : null
      Promise.all([charger(dalle(coords)), chargerAnnexe(urlMasque, annexe)]).then(([fond, couverture]) => {
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
  return comblerInterstices(new Couche(options))
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
