// Bloc « Opportunités » de l'accueil : filtre par catégorie, sans rechargement. La vedette est la
// première opportunité de la catégorie (ou de toutes), la liste montre les quatre suivantes.
// Le serveur rend l'état « Toutes » : sans JS, les pastilles restent masquées.
import { Controller } from "@hotwired/stimulus"

const LIGNES = 4

export default class extends Controller {
  static targets = ["filtres", "filtre", "vedette", "ligne", "vide"]

  // Sans opportunité datée à venir, la vue ne rend ni pastilles ni agenda : rien à afficher.
  connect() {
    if (this.hasFiltresTarget) this.filtresTarget.hidden = false
  }

  filtrer({ currentTarget, params: { cle } }) {
    this.filtreTargets.forEach((f) => f.setAttribute("aria-pressed", String(f === currentTarget)))
    const retenue = (el) => !cle || el.dataset.categorie === cle

    const vedette = this.vedetteTargets.find(retenue)
    this.vedetteTargets.forEach((v) => { v.hidden = v !== vedette })

    let restantes = LIGNES
    this.ligneTargets.forEach((l) => {
      const visible = restantes > 0 && retenue(l) && l.dataset.id !== vedette?.dataset.id
      l.hidden = !visible
      if (visible) restantes -= 1
    })
    this.videTarget.hidden = Boolean(vedette)
  }
}
