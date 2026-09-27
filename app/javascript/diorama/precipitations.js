// Pluie et neige : un canevas de particules au-dessus des dalles, sous les pins et les commandes.
// Il vit dans un volet Leaflet (z-index 450 : au-dessus des dalles et du socle, sous les marqueurs à
// 600), recalé à chaque déplacement pour rester fixe à l'écran.
//
// Sobriété : nombre de particules plafonné (proportionnel à la surface de la carte, voir
// diorama/reglages), 30 images par seconde au plus, canevas mis à l'échelle du devicePixelRatio
// (net sur écran Retina/HiDPI, tout en dessinant en pixels CSS), animation suspendue quand l'onglet
// est caché, et AUCUNE particule si l'appareil demande moins d'animations (prefers-reduced-motion) :
// l'ambiance reste une image fixe.
//
// Le flou de chaque plan de profondeur est calculé UNE FOIS par plan (un petit motif sur un canevas
// à part, ctx.filter appliqué une seule fois), puis simplement recopié (drawImage) à chaque image :
// appliquer ctx.filter à toute la scène à chaque image est très coûteux dès que le rendu graphique
// n'est pas accéléré (mesuré : ~30 i/s sans flou contre < 1 i/s avec, en rendu logiciel).
import { PLUIE, NEIGE, PARTICULES } from "diorama/reglages"

const ETROIT = "(max-width: 699.98px)"
const MOINS_DE_MOUVEMENT = "(prefers-reduced-motion: reduce)"
const INTERVALLE_MS = 1000 / 30 - 2 // 30 images par seconde au plus (marge pour la gigue de rAF)

const entre = ([a, b]) => a + Math.random() * (b - a)
const moyenne = ([a, b]) => (a + b) / 2

export function mouvementReduit() {
  return window.matchMedia(MOINS_DE_MOUVEMENT).matches
}

export class Precipitations {
  // type : "pluie" | "neige"
  constructor(L, carte, type) {
    this.L = L
    this.carte = carte
    this.type = type
    this.reduit = window.matchMedia(MOINS_DE_MOUVEMENT)
    this.etroit = window.matchMedia(ETROIT)
    this.surReduit = () => this.majActivite()
    this.surVisibilite = () => this.majActivite()
    this.surDeplacement = () => this.recaler()
    this.surTaille = () => this.dimensionner()
    this.reduit.addEventListener("change", this.surReduit)
    document.addEventListener("visibilitychange", this.surVisibilite)
    this.majActivite()
  }

  get reglages() { return this.type === "neige" ? NEIGE : PLUIE }

  // Échelle des TAILLES (rayon, longueur, épaisseur, dérive, flou) sur écran étroit ; le nombre de
  // particules, lui, suit déjà la surface réelle de la carte (voir peupler).
  get echelleTaille() { return this.etroit.matches ? PARTICULES.echelle_etroit : 1 }

  // Nombre de particules à l'écran (lu par les tests).
  get nombre() { return this.toile ? this.particules.length : 0 }

  majActivite() {
    if (this.reduit.matches) { this.retirer(); return }
    if (!this.toile) this.poser()
    if (document.hidden) this.suspendre()
    else this.reprendre()
  }

  poser() {
    const volet = this.carte.getPane("meteo") || this.carte.createPane("meteo")
    volet.style.zIndex = 450
    volet.style.pointerEvents = "none"
    this.toile = this.L.DomUtil.create("canvas", "acc-precipitations", volet)
    this.toile.setAttribute("aria-hidden", "true")
    this.ctx = this.toile.getContext("2d")
    this.carte.on("move zoomend viewreset", this.surDeplacement)
    this.carte.on("resize", this.surTaille)
    this.dimensionner()
    this.sprites = this.reglages.plans.map((pl) => this.creerSprite(pl))
    this.peupler()
  }

  // Le nombre de particules à 1920 × 1080 (reglages), mis à l'échelle de la surface réelle de la
  // carte, réparti entre les plans de profondeur (part fixe par plan, assignée à la naissance et
  // conservée à la renaissance).
  peupler() {
    const r = this.reglages
    const surface = this.largeur * this.hauteur
    const n = Math.max(PARTICULES.plancher, Math.round(r.particules_1920 * surface / PARTICULES.surface_1920))
    this.particules = []
    this.parPlan = r.plans.map(() => [])
    let assignees = 0
    r.plans.forEach((plan, i) => {
      const compte = i === r.plans.length - 1 ? n - assignees : Math.round(plan.part * n)
      assignees += compte
      for (let k = 0; k < compte; k++) {
        const p = this.naitre(true, i)
        this.particules.push(p)
        this.parPlan[i].push(p)
      }
    })
  }

  // Le motif (pré-flouté) d'un plan de profondeur : un flocon avec son contour, ou une goutte avec
  // son liseré, à la taille moyenne du plan. Dessiné une seule fois ; chaque particule le recopie
  // ensuite à l'échelle de son propre rayon/longueur (léger étirement, imperceptible dans l'écart
  // de taille d'un même plan).
  creerSprite(pl) {
    const r = this.reglages, echelle = this.echelleTaille
    const flou = pl.flou_px * echelle
    const c = document.createElement("canvas")
    const cx = c.getContext("2d")
    if (this.type === "neige") {
      const rayon = moyenne(pl.rayon_px) * echelle
      const contour = pl.contour_largeur_px * echelle
      const marge = flou * 3 + contour + 1
      c.width = c.height = Math.ceil((rayon + marge) * 2)
      cx.beginPath()
      cx.arc(c.width / 2, c.height / 2, rayon, 0, Math.PI * 2)
      cx.filter = flou ? `blur(${flou}px)` : "none"
      cx.fillStyle = r.couleur_flocon
      cx.fill()
      // Le contour reste NET (jamais flouté, même sur les plans les plus proches) : c'est lui qui
      // garde le flocon visible sur la maquette claire, un flou l'aurait dilué jusqu'à disparaître.
      cx.filter = "none"
      cx.strokeStyle = r.contour_couleur
      cx.lineWidth = contour
      cx.stroke()
      return { image: c, reference: rayon }
    }
    const longueur = moyenne(pl.longueur_px) * echelle
    const epaisseur = pl.epaisseur_px * echelle
    const dec = r.lisere_decalage_px * echelle
    const dx = -longueur * r.inclinaison, dy = -longueur
    const marge = flou * 3 + epaisseur + dec + 1
    c.width = Math.ceil(Math.abs(dx) + 2 * marge)
    c.height = Math.ceil(longueur + 2 * marge)
    const ax = dx < 0 ? c.width - marge : marge, ay = c.height - marge // ancre = bas du trait (position de la goutte)
    cx.filter = flou ? `blur(${flou}px)` : "none"
    cx.beginPath(); cx.moveTo(ax, ay); cx.lineTo(ax + dx, ay + dy)
    cx.strokeStyle = r.couleur
    cx.lineWidth = epaisseur
    cx.stroke()
    const long = Math.sqrt(1 + r.inclinaison * r.inclinaison)
    const px = dec / long, py = (dec / long) * -r.inclinaison
    cx.beginPath(); cx.moveTo(ax + px, ay + py); cx.lineTo(ax + dx + px, ay + dy + py)
    cx.strokeStyle = r.lisere_couleur
    cx.lineWidth = Math.max(1, echelle)
    cx.stroke()
    return { image: c, ax, ay, reference: longueur }
  }

  retirer() {
    this.suspendre()
    if (!this.toile) return
    this.carte.off("move zoomend viewreset", this.surDeplacement)
    this.carte.off("resize", this.surTaille)
    this.toile.remove()
    this.toile = null
    this.particules = []
    this.parPlan = []
  }

  detruire() {
    this.retirer()
    this.reduit.removeEventListener("change", this.surReduit)
    document.removeEventListener("visibilitychange", this.surVisibilite)
  }

  dimensionner() {
    const { x, y } = this.carte.getSize()
    this.largeur = x
    this.hauteur = y
    const dpr = window.devicePixelRatio || 1
    this.toile.width = Math.round(x * dpr)
    this.toile.height = Math.round(y * dpr)
    this.toile.style.width = `${x}px`
    this.toile.style.height = `${y}px`
    // Après un changement de taille du canevas, le contexte repart à zéro : pas de cumul.
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    this.recaler()
  }

  // Le volet suit la carte : on le ramène au coin haut-gauche de l'écran.
  recaler() {
    if (this.toile) this.L.DomUtil.setPosition(this.toile, this.carte.containerPointToLayerPoint([0, 0]))
  }

  // Une particule sur le plan `plan` (0 = le plus lointain) ; `partout` : n'importe où à l'écran
  // (au départ), sinon au-dessus du bord haut.
  naitre(partout, plan) {
    const r = this.reglages, pl = r.plans[plan]
    const y = partout ? Math.random() * this.hauteur : -20
    const echelle = this.echelleTaille
    if (this.type === "neige") {
      return { plan, x: Math.random() * this.largeur, y, v: entre(pl.vitesse_px_s), r: entre(pl.rayon_px) * echelle,
               phase: Math.random() * Math.PI * 2, frequence: 0.4 + Math.random() * 0.9,
               derive: r.derive_px * echelle * (0.7 + Math.random() * 0.6) }
    }
    return { plan, x: Math.random() * (this.largeur + this.hauteur * r.inclinaison) - this.hauteur * r.inclinaison, y,
             v: entre(pl.vitesse_px_s), l: entre(pl.longueur_px) * echelle }
  }

  reprendre() {
    if (this.image || !this.toile) return
    this.avant = performance.now()
    const pas = (t) => {
      this.image = requestAnimationFrame(pas)
      if (t - this.avant < INTERVALLE_MS) return
      const dt = Math.min(0.1, (t - this.avant) / 1000) // au retour d'un long arrêt, pas de saut
      this.avant = t
      this.dessiner(dt, t / 1000)
    }
    this.image = requestAnimationFrame(pas)
  }

  suspendre() {
    if (this.image) cancelAnimationFrame(this.image)
    this.image = null
  }

  // Dessiné plan par plan (le plus lointain d'abord), chaque particule recopiant le motif pré-flouté
  // de son plan (voir creerSprite) : aucun calcul de flou ici, seulement des drawImage.
  dessiner(dt, t) {
    const ctx = this.ctx, r = this.reglages
    ctx.clearRect(0, 0, this.largeur, this.hauteur)
    if (this.type === "neige") {
      r.plans.forEach((pl, i) => {
        const sprite = this.sprites[i]
        for (const p of this.parPlan[i]) {
          p.y += p.v * dt
          if (p.y > this.hauteur + 10) Object.assign(p, this.naitre(false, p.plan))
          const x = p.x + Math.sin(t * p.frequence + p.phase) * p.derive
          const k = p.r / sprite.reference, taille = sprite.image.width * k
          ctx.drawImage(sprite.image, x - taille / 2, p.y - taille / 2, taille, taille)
        }
      })
    } else {
      r.plans.forEach((pl, i) => {
        const sprite = this.sprites[i]
        for (const p of this.parPlan[i]) {
          p.y += p.v * dt
          p.x += p.v * dt * r.inclinaison
          if (p.y > this.hauteur + 20) Object.assign(p, this.naitre(false, p.plan))
          const k = p.l / sprite.reference
          ctx.drawImage(sprite.image, p.x - sprite.ax * k, p.y - sprite.ay * k, sprite.image.width * k, sprite.image.height * k)
        }
      })
    }
  }
}
