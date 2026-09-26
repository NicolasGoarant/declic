// Bottom sheet « Au centre de la vue » (mobile et tablette, < 1024 px).
//
// États : repliée (seule la poignée de 56 px dépasse, collée au-dessus de la tab bar) ou
// dépliée (≈ 55 % de la hauteur de l'écran). Sur bureau (≥ 1024 px) le volet est un panneau fixe :
// ce contrôleur n'y fait rien.
//
// Le déplacement passe par `transform: translateY` (CSS, 250 ms) : jamais la hauteur. Pendant un
// glissement, la variable CSS --glisse suit le doigt ; au relâchement, au-delà de 60 px vers le haut
// la sheet s'ouvre, au-delà de 60 px vers le bas elle se ferme, sinon elle revient où elle était.
import { Controller } from "@hotwired/stimulus"

const SEUIL_PX = 60
const DEPLACEMENT_MIN_PX = 6 // en dessous, c'est un tap et non un glissement
const BUREAU = "(min-width: 1024px)"

export default class extends Controller {
  static targets = ["poignee", "panneau"]

  connect() {
    this.ouverte = false
    this.mediaBureau = window.matchMedia(BUREAU)
    this.surChangement = () => this.appliquer()
    this.mediaBureau.addEventListener("change", this.surChangement)
    this.appliquer()
  }

  disconnect() {
    this.mediaBureau.removeEventListener("change", this.surChangement)
    clearTimeout(this.minuterieClic)
  }

  // Toute la barre est cliquable. Un clic qui suit un glissement est déjà traité : on l'ignore.
  basculer() {
    if (this.aGlisse) { this.aGlisse = false; return }
    this.definir(!this.ouverte, { focus: true })
  }

  ouvrir() { this.definir(true) }

  replier() { if (this.ouverte) this.definir(false) }

  echap(event) {
    if (event.key !== "Escape" || !this.ouverte || this.mediaBureau.matches) return
    const focusDedans = this.panneauTarget.contains(document.activeElement)
    this.definir(false)
    if (focusDedans) this.poigneeTarget.focus()
  }

  // ─── Glissement vertical sur la poignée ──────────────────────────────────────────────
  debutGlisse(event) {
    if (this.mediaBureau.matches || (event.pointerType === "mouse" && event.button !== 0)) return
    this.glissant = true
    this.aGlisse = false
    this.y0 = event.clientY
    this.dy = 0
    // Course totale = ce qui dépasse de la poignée quand la sheet est dépliée.
    this.course = this.element.offsetHeight - this.poigneeTarget.offsetHeight
    this.poigneeTarget.setPointerCapture?.(event.pointerId)
  }

  glisse(event) {
    if (!this.glissant) return
    const dy = event.clientY - this.y0
    if (!this.aGlisse && Math.abs(dy) < DEPLACEMENT_MIN_PX) return
    this.aGlisse = true
    this.element.classList.add("acc-volet--glisse")
    // Repliée : on ne peut que monter ; dépliée : que descendre.
    this.dy = this.ouverte ? Math.min(Math.max(dy, 0), this.course) : Math.max(Math.min(dy, 0), -this.course)
    this.element.style.setProperty("--glisse", `${this.dy}px`)
  }

  finGlisse() {
    if (!this.glissant) return
    this.glissant = false
    this.element.classList.remove("acc-volet--glisse")
    if (!this.aGlisse) return // simple tap : le clic s'en charge
    let ouverte = this.ouverte
    if (this.dy < -SEUIL_PX) ouverte = true
    else if (this.dy > SEUIL_PX) ouverte = false
    this.definir(ouverte)
    // Le clic qui suit le relâchement est avalé par basculer() ; si aucun clic ne vient, on réarme.
    clearTimeout(this.minuterieClic)
    this.minuterieClic = setTimeout(() => { this.aGlisse = false }, 120)
  }

  // ─── État ────────────────────────────────────────────────────────────────────────────
  definir(ouverte, { focus = false } = {}) {
    this.ouverte = ouverte
    this.element.style.removeProperty("--glisse")
    this.appliquer()
    // Le focus va sur la première fiche à l'ouverture (clavier ou tap sur la poignée).
    if (ouverte && focus && !this.mediaBureau.matches) {
      this.panneauTarget.querySelector(".fiche-lien")?.focus({ preventScroll: true })
    }
  }

  appliquer() {
    const bureau = this.mediaBureau.matches
    const ouverte = this.ouverte && !bureau
    this.element.classList.toggle("acc-volet--ouvert", ouverte)
    this.poigneeTarget.setAttribute("aria-expanded", String(this.ouverte))
    this.poigneeTarget.setAttribute("aria-label",
      this.ouverte ? "Replier les lieux au centre de la vue" : "Afficher les lieux au centre de la vue")
    // Repliée, la sheet est hors de l'écran : ses fiches ne doivent être ni focalisables ni lues.
    this.panneauTarget.inert = !bureau && !this.ouverte
  }
}
