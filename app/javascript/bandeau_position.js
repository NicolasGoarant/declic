// Bandeau discret et fermable lié à la géolocalisation (partial shared/_bandeau_position) : invitation
// « Activer ma position », aide quand la position est bloquée, ou « Position indisponible ».
// Écoute l'état publié par geoloc_auto.js ; ne bloque jamais la page.
import { demander } from "geoloc_auto"

const MESSAGES = {
  invite: "Voyez les opportunités près de chez vous : partagez votre position.",
  refuse: "Position désactivée. Pour trouver les opportunités près de vous, réactivez la position dans le cadenas de la barre d'adresse.",
  echec: "Position indisponible."
}

function monter(bandeau) {
  const texte = bandeau.querySelector("[data-bandeau-texte]")
  const activer = bandeau.querySelector("[data-bandeau-activer]")
  let ferme = false

  const afficher = (etat) => {
    const message = MESSAGES[etat]
    bandeau.hidden = ferme || !message
    if (!message) return
    texte.textContent = message
    activer.hidden = etat !== "invite"
    bandeau.dataset.etat = etat
  }

  window.addEventListener("declic:position-etat", (e) => afficher(e.detail.etat))
  activer.addEventListener("click", () => { activer.disabled = true; demander(); setTimeout(() => { activer.disabled = false }, 1000) })
  bandeau.querySelector("[data-bandeau-fermer]").addEventListener("click", () => { ferme = true; bandeau.hidden = true })
  afficher(window.declicPositionEtat)
}

document.querySelectorAll("[data-bandeau-position]").forEach(monter)
