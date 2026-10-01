// Onglets accessibles (bloc « Dans les médias » de l'accueil) : un onglet choisi au clic ou au focus
// montre son panneau ; flèches, Début et Fin déplacent le focus. Sans JS, tous les panneaux restent
// visibles et la rangée d'onglets est masquée.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["liste", "onglet", "panneau"]

  connect() {
    this.listeTarget.hidden = false
    this.element.classList.add("onglets--actifs")
    this.montrer(Math.max(0, this.ongletTargets.findIndex((o) => o.getAttribute("aria-selected") === "true")))
  }

  choisir({ currentTarget }) { this.montrer(this.ongletTargets.indexOf(currentTarget)) }

  clavier(event) {
    const n = this.ongletTargets.length, i = this.ongletTargets.indexOf(event.currentTarget)
    const cible = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: n - 1 }[event.key]
    if (cible === undefined) return
    event.preventDefault()
    this.ongletTargets[(cible + n) % n].focus() // le focus choisit l'onglet
  }

  montrer(index) {
    this.ongletTargets.forEach((o, i) => {
      o.setAttribute("aria-selected", String(i === index))
      o.tabIndex = i === index ? 0 : -1
    })
    this.panneauTargets.forEach((p, i) => { p.hidden = i !== index })
  }
}
