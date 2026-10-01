// Blocs de l'accueil : chacun apparaît en fondu, avec un léger glissement vers le haut, la première
// fois qu'il entre dans la fenêtre. Sans JS, ou si l'on a demandé moins d'animations, tout est
// affiché d'emblée (la classe `apparition--active` n'est jamais posée).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return

    this.observateur = new IntersectionObserver((entrees) => {
      entrees.filter((e) => e.isIntersecting).forEach((e) => {
        e.target.classList.add("bloc--vu")
        this.observateur.unobserve(e.target)
      })
    }, { rootMargin: "0px 0px -10% 0px" })
    // Les blocs déjà à l'écran au chargement restent visibles (pas de clignotement).
    this.element.querySelectorAll(":scope > .bloc").forEach((bloc) => {
      if (bloc.getBoundingClientRect().top < innerHeight) bloc.classList.add("bloc--vu")
      else this.observateur.observe(bloc)
    })
    this.element.classList.add("apparition--active")
  }

  disconnect() { this.observateur?.disconnect() }
}
