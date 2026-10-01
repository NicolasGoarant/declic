// Carrousel de la page d'accueil (bloc Témoignages : cartes en éventail). Le contrôleur ne fait que
// tenir l'index : chaque diapositive reçoit sa position relative (--pos, data-pos), son écart au
// centre (--ecart) et aria-current ; la mise en forme est en CSS (accueil_blocs.css). Flèches,
// clic sur une carte, flèches du clavier, balayage au doigt ; la liste boucle. Sans JS, la piste
// reste une rangée défilante (classe carrousel--actif absente).
import { Controller } from "@hotwired/stimulus"

const SEUIL_GLISSE = 40 // px

export default class extends Controller {
  static targets = ["piste", "diapo"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    // Un clic qui termine un balayage ne doit ni suivre un lien ni choisir une carte.
    this.filtrerClic = (event) => {
      if (!this.vientDeGlisser) return
      event.preventDefault()
      event.stopPropagation()
    }
    this.element.addEventListener("click", this.filtrerClic, true)
    this.element.classList.add("carrousel--actif")
    this.maj()
  }

  disconnect() {
    this.element.removeEventListener("click", this.filtrerClic, true)
  }

  precedent() { this.aller(this.indexValue - 1) }
  suivant() { this.aller(this.indexValue + 1) }
  choisir({ params: { index } }) { this.aller(index) }

  aller(i) {
    const n = this.diapoTargets.length
    if (n) this.indexValue = ((i % n) + n) % n
  }

  indexValueChanged() { this.maj() }

  clavier(event) {
    if (event.key === "ArrowLeft") { event.preventDefault(); this.precedent() }
    if (event.key === "ArrowRight") { event.preventDefault(); this.suivant() }
  }

  debutGlisse(event) {
    this.depart = { x: event.clientX, y: event.clientY }
  }

  finGlisse(event) {
    if (!this.depart) return
    const dx = event.clientX - this.depart.x, dy = event.clientY - this.depart.y
    this.depart = null
    if (Math.abs(dx) < SEUIL_GLISSE || Math.abs(dx) < Math.abs(dy)) return
    this.vientDeGlisser = true
    setTimeout(() => { this.vientDeGlisser = false }, 0)
    dx < 0 ? this.suivant() : this.precedent()
  }

  annulerGlisse() { this.depart = null }

  // Position de chaque diapositive autour de la courante, au plus court dans la boucle.
  maj() {
    const n = this.diapoTargets.length, moitie = Math.floor(n / 2)
    this.diapoTargets.forEach((diapo, i) => {
      const pos = ((i - this.indexValue + moitie + n) % n) - moitie
      diapo.style.setProperty("--pos", pos)
      diapo.style.setProperty("--ecart", Math.abs(pos))
      diapo.dataset.pos = pos
      diapo.setAttribute("aria-current", String(pos === 0))
    })
  }
}
