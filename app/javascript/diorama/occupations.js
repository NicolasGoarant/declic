// Les OCCUPATIONS SAISONNIÈRES des places (sapin, grande roue, patinoire, marché de Noël…), saisies à la main dans
// config/diorama/occupations_places.yml et reçues avec les tuiles (DioramaOccupations#pour_js).
//
// Une installation se montre si le jour de Nancy est dans [debut, fin] et si le zoom est dans sa liste. C'est une image
// FIXE posée sur la carte (L.imageOverlay : Leaflet la place et la met à l'échelle, zoom animé compris), sans boucle
// d'animation : aucun coût par image. Deux volets : l'objet, assombri le soir comme les vivants (ses couleurs sont celles
// du plein jour), puis ses lumières (guirlandes), au-dessus et sans assombrissement, dosées selon le moment.
//
// Occlusion, calculée UNE fois à la pose : la règle des colonnes des bateaux et des vivants. Dans chaque colonne de
// l'image, si le pied de l'objet (son pixel opaque le plus bas) tombe sur un VOLUME de la carte de propriété (houppier,
// façade posés devant lui), la partie de l'objet couverte par ce volume, du pied jusqu'au haut du volume, est effacée.
// Les deux images (objet et lumières) passent par le même masque, puis sont posées telles quelles.
import { OCCUPATIONS } from "diorama/reglages"
import { lireCodes } from "diorama/vivants"

const NIVEAU_REPERE = 8
const FUSEAU = "Europe/Paris"
const COTE = 256
const estVolume = (c) => c === 2 || c === 4 // propriété : 1 sol posé, 2 volume posé, 3 sol repris, 4 volume repris
const MONTEE_MAX = 200 // px du niveau 8 : hauteur maximale d'un volume qui masque (comme les vivants)

// "AAAA-MM-JJ" du jour à Nancy, quel que soit le fuseau de l'appareil.
export function jourANancy(date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: FUSEAU, year: "numeric", month: "2-digit", day: "2-digit" }).format(date)
}

// Les installations en place le jour `jour` (ISO : la comparaison de chaînes suit l'ordre des dates), bornes incluses.
export function enPlace(liste, jour) {
  return (liste || []).filter((o) => o.debut <= jour && jour <= o.fin)
}

function lireImageLocale(url) {
  return new Promise((ok, ko) => {
    const im = new Image()
    im.onload = () => ok(im)
    im.onerror = () => ko(new Error(url))
    im.src = url
  })
}

export class Occupations {
  // `propriete(x, y)` : URL de la dalle de codes 8/x/y du style affiché, ou null si elle n'est pas publiée (pas d'occlusion là).
  constructor(L, carte, { projection, liste, jour, propriete = null, style = null }) {
    this.L = L
    this.carte = carte
    this.jour = jour
    this.style = style
    this.propriete = propriete
    this.volets = ["occupations", "occupations-lumieres"].map((nom, i) => {
      const volet = carte.getPane(nom) || carte.createPane(nom)
      volet.style.zIndex = OCCUPATIONS.z_index + i
      volet.style.pointerEvents = "none"
      return volet
    })
    this.poses = enPlace(liste, jour).map((o) => this.poser(o, projection)).filter(Boolean)
    this.surZoom = () => this.majZoom()
    carte.on("zoomend", this.surZoom)
    this.majZoom()
  }

  // Les deux calques d'une installation : l'image a son ancre (le pied) sur la position projetée au niveau 8.
  poser(o, projection) {
    const [px, py] = projection.pixel(o.lat, o.lon, o.altitude_m ?? undefined)
    if (!projection.dansLaMosaique([px, py])) return null
    const L = this.L, carte = this.carte
    const calque = (url, volet, l, h) => {
      const hg = carte.unproject(L.point(px - o.ancre[0] / o.k, py - o.ancre[1] / o.k), NIVEAU_REPERE)
      const bd = carte.unproject(L.point(px + (l - o.ancre[0]) / o.k, py + (h - o.ancre[1]) / o.k), NIVEAU_REPERE)
      return L.imageOverlay(url, L.latLngBounds(hg, bd), { pane: volet, interactive: false, alt: "", className: "diorama-occupation" })
    }
    const pose = { o, calques: [] }
    const ox = px - o.ancre[0] / o.k, oy = py - o.ancre[1] / o.k // coin haut-gauche de l'image, en px du niveau 8
    Promise.all([lireImageLocale(o.image), o.lumieres ? lireImageLocale(o.lumieres) : null])
      .then(([objet, lumieres]) => this.masquer(objet, lumieres, o.k, ox, oy))
      .then(([objet, lumieres, l, h]) => {
        if (this.detruit) return
        pose.calques = [calque(objet, "occupations", l, h)]
        if (lumieres) pose.calques.push(calque(lumieres, "occupations-lumieres", l, h))
        this.majZoom()
      })
      .catch((erreur) => console.warn(`occupations : ${o.id}`, erreur))
    return pose
  }

  // Les deux images après la règle des colonnes : [url objet, url lumières | null, largeur, hauteur]. Sans carte de
  // propriété (dalle non publiée, illisible), l'image reste entière.
  async masquer(objet, lumieres, k, ox, oy) {
    const l = objet.naturalWidth, h = objet.naturalHeight
    const toile = (im) => {
      const c = document.createElement("canvas"); c.width = l; c.height = h
      const ctx = c.getContext("2d", { willReadFrequently: true }); ctx.drawImage(im, 0, 0, l, h)
      return [c, ctx]
    }
    const [co, xo] = toile(objet)
    const [cl, xl] = lumieres ? toile(lumieres) : [null, null]
    if (this.propriete) {
      const codes = new Map()
      const tx0 = Math.floor((ox) / COTE), tx1 = Math.floor((ox + l / k) / COTE)
      const ty0 = Math.floor((oy - MONTEE_MAX) / COTE), ty1 = Math.floor((oy + h / k) / COTE)
      const lectures = []
      for (let tx = tx0; tx <= tx1; tx++) {
        for (let ty = ty0; ty <= ty1; ty++) {
          const url = this.propriete(tx, ty)
          if (url) lectures.push(lireCodes(url).then((d) => codes.set(`${tx}/${ty}`, d), () => null))
        }
      }
      await Promise.all(lectures)
      const code = (x, y) => {
        x = Math.floor(x); y = Math.floor(y)
        const d = codes.get(`${Math.floor(x / COTE)}/${Math.floor(y / COTE)}`)
        return d ? d.a[(y - Math.floor(y / COTE) * COTE) * d.w + (x - Math.floor(x / COTE) * COTE)] : 0
      }
      const a = xo.getImageData(0, 0, l, h).data
      for (let i = 0; i < l; i++) {
        let j = h - 1
        while (j >= 0 && a[4 * (j * l + i) + 3] < 128) j--
        if (j < 0) continue
        const x8 = ox + (i + 0.5) / k, pied = oy + (j + 0.5) / k
        if (!estVolume(code(x8, pied))) continue
        let haut = Math.floor(pied)
        while (haut - 1 > pied - MONTEE_MAX && estVolume(code(x8, haut - 0.5))) haut--
        const r = Math.max(0, Math.floor((haut - oy) * k))
        xo.clearRect(i, r, 1, h - r)
        xl?.clearRect(i, r, 1, h - r)
      }
    }
    return [co.toDataURL(), cl ? cl.toDataURL() : null, l, h]
  }

  majZoom() {
    const z = Math.round(this.carte.getZoom())
    for (const { o, calques } of this.poses) {
      const voulu = o.zooms.includes(z)
      for (const c of calques) {
        if (voulu && !this.carte.hasLayer(c)) c.addTo(this.carte)
        else if (!voulu && this.carte.hasLayer(c)) c.remove()
      }
    }
  }

  // `teinte` : filtre CSS de l'objet (celui des vivants) ; les lumières suivent OCCUPATIONS.lumieres[moment].
  majMoment(moment, teinte = "") {
    this.volets[0].style.filter = teinte
    this.volets[1].style.opacity = String(OCCUPATIONS.lumieres[moment] ?? 0)
  }

  // Ids des installations posées (essais, tests système).
  ids() { return this.poses.map((p) => p.o.id) }

  detruire() {
    this.detruit = true
    this.carte.off("zoomend", this.surZoom)
    for (const { calques } of this.poses) calques.forEach((c) => c.remove())
    this.poses = []
  }
}
