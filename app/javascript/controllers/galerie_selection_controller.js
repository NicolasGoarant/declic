import { Controller } from "@hotwired/stimulus"

// Galerie d'administration : « tout sélectionner » et décompte « N sélectionnées ».
// Amélioration seulement : les cases des cartes et les actions groupées fonctionnent sans JavaScript
// (attribut form="selection-groupee"). La case « tout » est cachée dans le HTML et révélée ici.
export default class extends Controller {
  static targets = ["toutes", "libelle"]

  connect() {
    this.suivre = (e) => { if (e.target.matches?.("input.case-carte")) this.mettreAJour() }
    document.addEventListener("change", this.suivre) // les cartes sont des voisines du contrôleur, pas ses enfants
    this.toutesTarget.hidden = false
    this.mettreAJour()
  }

  disconnect() {
    document.removeEventListener("change", this.suivre)
  }

  basculer() {
    this.cases.forEach((c) => { c.checked = this.toutesTarget.checked })
    this.mettreAJour()
  }

  mettreAJour() {
    const cochees = this.cases.filter((c) => c.checked).length
    this.libelleTarget.textContent = cochees === 0 ? "Aucune sélection" : `${cochees} sélectionnée${cochees > 1 ? "s" : ""}`
    this.toutesTarget.checked = cochees > 0 && cochees === this.cases.length
    this.toutesTarget.indeterminate = cochees > 0 && cochees < this.cases.length
  }

  get cases() {
    return Array.from(document.querySelectorAll("input.case-carte"))
  }
}
