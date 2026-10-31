import { Controller } from "@hotwired/stimulus"

// Écran d'étiquetage : un commentaire s'enregistre en quittant le champ, et un avis amène le cas
// suivant à l'écran. Un clic sur un avis enregistre aussi le commentaire : l'attente s'annule alors.
export default class extends Controller {
  disconnect() {
    this.annulerAttente()
  }

  enregistrerCommentaire() {
    this.annulerAttente()
    this.attente = setTimeout(() => this.element.requestSubmit(), 300)
  }

  annulerAttente() {
    clearTimeout(this.attente)
  }

  suivant(event) {
    const { success, formSubmission } = event.detail
    if (!success || formSubmission.submitter?.name !== "avis") return
    this.element.closest(".etiq")?.nextElementSibling?.scrollIntoView({ block: "nearest" })
  }
}
