// Géolocalisation automatique à l'arrivée sur le site (toutes les pages qui chargent application.js).
// La demande n'est faite qu'une fois par navigateur : la clé est posée AVANT d'interroger, donc un refus,
// un timeout ou un onglet fermé pendant l'invite ne la relancent pas. Ensuite, si la permission est déjà
// accordée, la position est relue en silence (pas d'invite) pour que chaque page la retrouve.
// Aucun échec n'est jamais montré : le bouton « Me localiser » reste le repli.
// Succès : window.declicPosition = { lat, lon } + événement window « declic:position ».
const CLE = "declic:geoloc-auto"
const OPTIONS = { enableHighAccuracy: false, timeout: 8000, maximumAge: 10 * 60 * 1000 }

function dejaDemandee() {
  try { return localStorage.getItem(CLE) !== null } catch { return true } // stockage coupé : on ne harcèle pas
}

function marquerDemandee() {
  try { localStorage.setItem(CLE, String(Date.now())) } catch { /* stockage indisponible */ }
}

function interroger() {
  navigator.geolocation.getCurrentPosition(
    ({ coords }) => {
      window.declicPosition = { lat: coords.latitude, lon: coords.longitude }
      window.dispatchEvent(new CustomEvent("declic:position", { detail: window.declicPosition }))
    },
    () => { /* refus, indisponible, timeout : silence, repli sur le bouton */ },
    OPTIONS
  )
}

async function demarrer() {
  if (!("geolocation" in navigator) || !window.isSecureContext) return
  try {
    const etat = navigator.permissions ? (await navigator.permissions.query({ name: "geolocation" })).state : "prompt"
    if (etat === "denied") return
    if (etat === "granted") { marquerDemandee(); interroger(); return }
  } catch { /* Permissions API absente (Safari ancien) : on suit la clé locale */ }
  if (dejaDemandee()) return
  marquerDemandee()
  interroger()
}

demarrer()
