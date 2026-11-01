import { Controller } from "@hotwired/stimulus"

// Cases à cocher d'une liste + « tout sélectionner » : le bouton d'action reste désactivé tant
// qu'aucune case n'est cochée, et indique le nombre d'éléments sélectionnés.
export default class extends Controller {
  static targets = ["case", "tout", "bouton", "compte"]

  connect() { this.maj() }

  basculer() {
    this.caseTargets.forEach((c) => { c.checked = this.toutTarget.checked })
    this.maj()
  }

  maj() {
    const n = this.caseTargets.filter((c) => c.checked).length
    this.boutonTarget.disabled = n === 0
    this.compteTarget.textContent = n === 0 ? "" : `${n} sélectionné${n > 1 ? "s" : ""}`
    this.toutTarget.checked = n > 0 && n === this.caseTargets.length
    this.toutTarget.indeterminate = n > 0 && n < this.caseTargets.length
  }
}
