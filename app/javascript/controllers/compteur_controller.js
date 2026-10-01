// « L'impact local » : chaque nombre monte de 0 à sa valeur (data-valeur) la première fois que la
// bande entre dans la fenêtre. Le serveur a déjà écrit la valeur finale : sans JS, ou si l'on a
// demandé moins d'animations, rien ne bouge.
import { Controller } from "@hotwired/stimulus"

const DUREE = 1200 // ms
const format = new Intl.NumberFormat("fr-FR")
const ecrire = (el, n) => { el.textContent = format.format(n).replace(/\s/g, " ") }
const adoucir = (t) => 1 - Math.pow(1 - t, 3) // ease-out cubique

export default class extends Controller {
  static targets = ["nombre"]

  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return

    this.nombreTargets.forEach((el) => ecrire(el, 0))
    this.observateur = new IntersectionObserver((entrees) => {
      if (!entrees.some((e) => e.isIntersecting)) return
      this.observateur.disconnect()
      this.animer()
    }, { threshold: 0.4 })
    this.observateur.observe(this.element)
  }

  disconnect() {
    this.observateur?.disconnect()
    cancelAnimationFrame(this.image)
    this.nombreTargets.forEach((el) => ecrire(el, Number(el.dataset.valeur)))
  }

  animer() {
    const debut = performance.now()
    const pas = (maintenant) => {
      const t = Math.min(1, (maintenant - debut) / DUREE)
      this.nombreTargets.forEach((el) => ecrire(el, Math.round(Number(el.dataset.valeur) * adoucir(t))))
      if (t < 1) this.image = requestAnimationFrame(pas)
    }
    this.image = requestAnimationFrame(pas)
  }
}
