// Pluie et neige : un canevas de particules au-dessus des dalles, sous les pins et les commandes.
// Il vit dans un volet Leaflet (z-index 450 : au-dessus des dalles et du socle, sous les marqueurs à
// 600), recalé à chaque déplacement pour rester fixe à l'écran.
//
// Sobriété : nombre de particules plafonné (moitié sur écran étroit), 30 images par seconde au plus,
// canevas à un pixel par pixel CSS (des traits fins et des flocons flous n'en demandent pas plus),
// animation suspendue quand l'onglet est caché, et AUCUNE particule si l'appareil demande moins
// d'animations (prefers-reduced-motion) : l'ambiance reste une image fixe.
import { PLUIE, NEIGE } from "diorama/reglages"

const ETROIT = "(max-width: 699.98px)"
const MOINS_DE_MOUVEMENT = "(prefers-reduced-motion: reduce)"
const INTERVALLE_MS = 1000 / 30 - 2 // 30 images par seconde au plus (marge pour la gigue de rAF)

const entre = ([a, b]) => a + Math.random() * (b - a)

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
    this.surReduit = () => this.majActivite()
    this.surVisibilite = () => this.majActivite()
    this.surDeplacement = () => this.recaler()
    this.surTaille = () => this.dimensionner()
    this.reduit.addEventListener("change", this.surReduit)
    document.addEventListener("visibilitychange", this.surVisibilite)
    this.majActivite()
  }

  get reglages() { return this.type === "neige" ? NEIGE : PLUIE }

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
    const plafond = this.reglages.particules
    const n = window.matchMedia(ETROIT).matches ? Math.round(plafond / 2) : plafond
    this.particules = Array.from({ length: n }, () => this.naitre(true))
  }

  retirer() {
    this.suspendre()
    if (!this.toile) return
    this.carte.off("move zoomend viewreset", this.surDeplacement)
    this.carte.off("resize", this.surTaille)
    this.toile.remove()
    this.toile = null
    this.particules = []
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
    this.toile.width = x
    this.toile.height = y
    this.toile.style.width = `${x}px`
    this.toile.style.height = `${y}px`
    this.recaler()
  }

  // Le volet suit la carte : on le ramène au coin haut-gauche de l'écran.
  recaler() {
    if (this.toile) this.L.DomUtil.setPosition(this.toile, this.carte.containerPointToLayerPoint([0, 0]))
  }

  // Une particule ; `partout` : n'importe où à l'écran (au départ), sinon au-dessus du bord haut.
  naitre(partout) {
    const r = this.reglages
    const y = partout ? Math.random() * this.hauteur : -20
    if (this.type === "neige") {
      return { x: Math.random() * this.largeur, y, v: entre(r.vitesse_px_s), r: entre(r.rayon_px),
               phase: Math.random() * Math.PI * 2, frequence: 0.4 + Math.random() * 0.9, derive: r.derive_px * (0.4 + Math.random() * 0.6) }
    }
    return { x: Math.random() * (this.largeur + this.hauteur * r.inclinaison) - this.hauteur * r.inclinaison, y,
             v: entre(r.vitesse_px_s), l: entre(r.longueur_px) }
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

  dessiner(dt, t) {
    const ctx = this.ctx, r = this.reglages
    ctx.clearRect(0, 0, this.largeur, this.hauteur)
    ctx.beginPath()
    if (this.type === "neige") {
      for (const p of this.particules) {
        p.y += p.v * dt
        const x = p.x + Math.sin(t * p.frequence + p.phase) * p.derive
        if (p.y > this.hauteur + 10) Object.assign(p, this.naitre(false))
        ctx.moveTo(x + p.r, p.y)
        ctx.arc(x, p.y, p.r, 0, Math.PI * 2)
      }
      ctx.fillStyle = r.couleur_flocon
      ctx.fill()
    } else {
      for (const p of this.particules) {
        p.y += p.v * dt
        p.x += p.v * dt * r.inclinaison
        if (p.y > this.hauteur + 20) Object.assign(p, this.naitre(false))
        ctx.moveTo(p.x, p.y)
        ctx.lineTo(p.x - p.l * r.inclinaison, p.y - p.l)
      }
      ctx.strokeStyle = r.couleur
      ctx.lineWidth = 1
      ctx.stroke()
    }
  }
}
