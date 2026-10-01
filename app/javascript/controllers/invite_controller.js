// Bouton d'invite sous le diorama (≥ 768 px) : fait défiler en douceur vers les blocs de la page, et
// s'efface en fondu dès que la page a défilé de plus de SEUIL px (il revient tout en haut).
import { Controller } from "@hotwired/stimulus"

const SEUIL = 80

export default class extends Controller {
  static values = { cible: String }

  connect() { this.surDefilement() }

  descendre() {
    const cible = document.querySelector(this.cibleValue)
    if (!cible) return
    const calme = matchMedia("(prefers-reduced-motion: reduce)").matches
    cible.scrollIntoView({ behavior: calme ? "auto" : "smooth", block: "start" })
  }

  surDefilement() {
    const masque = window.scrollY > SEUIL
    this.element.classList.toggle("acc-invite--masque", masque)
    this.element.tabIndex = masque ? -1 : 0 // invisible : hors de l'ordre de tabulation
  }
}
