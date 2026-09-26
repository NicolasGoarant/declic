// Galerie d'une fiche : défilement horizontal natif aimanté (glissement au doigt sur mobile),
// flèches, compteur « 1/5 », vignettes, flèches du clavier. Une photo qui ne se charge pas
// quitte la galerie ; s'il n'en reste aucune, l'icône de la catégorie prend la place.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["piste", "diapo", "compteur", "fleche", "vignettes", "vignette", "vide"]

  connect() {
    // Une image déjà en échec avant l'arrivée du contrôleur n'enverra plus d'événement « error ».
    this.diapoTargets.forEach((d) => {
      const img = d.querySelector("img")
      if (img?.complete && img.naturalWidth === 0) this.retirer(d)
    })
    this.maj()
  }

  photoMorte(event) {
    this.retirer(event.target.closest(".fch-galerie-diapo"))
  }

  retirer(diapo) {
    if (!diapo || diapo.hidden) return
    const i = this.diapoTargets.indexOf(diapo)
    diapo.hidden = true
    if (this.vignetteTargets[i]) this.vignetteTargets[i].hidden = true
    this.maj()
  }

  get visibles() { return this.diapoTargets.filter((d) => !d.hidden) }

  get courant() {
    if (!this.hasPisteTarget) return 0
    const largeur = this.pisteTarget.clientWidth || 1
    return Math.min(Math.round(this.pisteTarget.scrollLeft / largeur), Math.max(this.visibles.length - 1, 0))
  }

  aller(i) {
    const diapo = this.visibles[i]
    if (!diapo) return
    const doux = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.pisteTarget.scrollTo({ left: diapo.offsetLeft, behavior: doux ? "smooth" : "auto" })
  }

  precedent() {
    const n = this.visibles.length
    if (n) this.aller((this.courant - 1 + n) % n)
  }

  suivant() {
    const n = this.visibles.length
    if (n) this.aller((this.courant + 1) % n)
  }

  choisir({ params: { index } }) {
    this.aller(this.visibles.indexOf(this.diapoTargets[index]))
  }

  clavier(event) {
    if (event.key === "ArrowLeft") { event.preventDefault(); this.precedent() }
    if (event.key === "ArrowRight") { event.preventDefault(); this.suivant() }
  }

  defiler() {
    cancelAnimationFrame(this.image)
    this.image = requestAnimationFrame(() => this.maj())
  }

  maj() {
    const visibles = this.visibles, n = visibles.length, i = this.courant
    this.videTarget.hidden = n > 0
    if (this.hasPisteTarget) this.pisteTarget.hidden = n === 0
    if (this.hasCompteurTarget) {
      this.compteurTarget.hidden = n < 2
      this.compteurTarget.textContent = `${i + 1}/${n}`
    }
    this.flecheTargets.forEach((f) => { f.hidden = n < 2 })
    if (this.hasVignettesTarget) this.vignettesTarget.hidden = n < 2
    const actif = visibles[i]
    this.vignetteTargets.forEach((v, k) => v.setAttribute("aria-current", String(this.diapoTargets[k] === actif)))
  }
}
