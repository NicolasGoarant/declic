// Fiche Opportunité / Belle Histoire : retour, favoris (même stockage local que /labo/accueil),
// partage natif, copie du lien, photos mortes des vignettes.
import { Controller } from "@hotwired/stimulus"

const CLE_FAVORIS = "declic:favoris" // diorama_controller.js

export default class extends Controller {
  static values = { url: String, titre: String, favori: String }
  static targets = ["partageNatif", "statut", "favori"]

  connect() {
    if (typeof navigator.share === "function") this.partageNatifTargets.forEach((b) => { b.hidden = false })
    this.majFavori()
    // Vignettes : une photo morte laisse voir l'icône de catégorie posée dessous.
    this.surErreur = (e) => { if (e.target.matches?.("img[data-repli]")) e.target.remove() }
    this.element.addEventListener("error", this.surErreur, true)
    this.element.querySelectorAll("img[data-repli]").forEach((img) => {
      if (img.complete && img.naturalWidth === 0) img.remove()
    })
  }

  disconnect() {
    this.element.removeEventListener("error", this.surErreur, true)
  }

  // Arrivé depuis une page du site : on y retourne (position de défilement comprise).
  retour(event) {
    try {
      if (document.referrer && new URL(document.referrer).origin === location.origin && history.length > 1) {
        event.preventDefault()
        history.back()
      }
    } catch { /* referrer illisible : le lien suit son href */ }
  }

  // ─── Favoris ─────────────────────────────────────────────────────────────────────────
  lireFavoris() {
    try { return new Set(JSON.parse(localStorage.getItem(CLE_FAVORIS) || "[]")) } catch { return new Set() }
  }

  basculerFavori() {
    if (!this.favoriValue) return
    const favoris = this.lireFavoris()
    favoris.has(this.favoriValue) ? favoris.delete(this.favoriValue) : favoris.add(this.favoriValue)
    try {
      localStorage.setItem(CLE_FAVORIS, JSON.stringify([...favoris]))
    } catch {
      this.annoncer("Favoris indisponibles sur ce navigateur.")
      return
    }
    this.majFavori()
    this.annoncer(favoris.has(this.favoriValue) ? "Ajoutée à vos favoris." : "Retirée de vos favoris.")
  }

  majFavori() {
    const favori = this.favoriValue && this.lireFavoris().has(this.favoriValue)
    this.favoriTargets.forEach((b) => {
      b.setAttribute("aria-pressed", String(!!favori))
      b.querySelector("span").textContent = favori ? "Dans vos favoris" : "Ajouter aux favoris"
    })
  }

  // ─── Partage ─────────────────────────────────────────────────────────────────────────
  async partager() {
    try {
      await navigator.share({ title: this.titreValue, url: this.urlValue })
    } catch { /* partage annulé */ }
  }

  async copier() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.annoncer("Lien copié.")
    } catch {
      this.annoncer(`Copiez ce lien : ${this.urlValue}`)
    }
  }

  annoncer(texte) {
    if (!this.hasStatutTarget) return
    this.statutTarget.textContent = texte
    clearTimeout(this.minuterie)
    this.minuterie = setTimeout(() => { this.statutTarget.textContent = "" }, 4000)
  }
}
