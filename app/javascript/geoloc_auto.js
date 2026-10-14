// Géolocalisation à l'arrivée sur le site (toutes les pages qui chargent application.js), partagée par
// les cartes (diorama_controller), la liste (explorateur_controller), /labo/diorama et le bandeau d'aide
// (bandeau_position.js).
//
// À l'arrivée, selon l'état de la permission :
//   prompt  → demande immédiate (le navigateur affiche son invite) ; sans réponse au bout de 10 s
//             (navigateur qui veut un geste), le bandeau propose « Activer ma position » ;
//   granted → position relue sans invite ;
//   denied  → bandeau d'aide (réactiver dans le cadenas) ;
//   pas d'API Permissions → bandeau d'invitation (un clic déclenche l'invite).
// Un refus explicite est mémorisé 7 jours : plus de demande automatique, le bouton « Me localiser » reste actif.
//
// Succès : window.declicPosition = { lat, lon } + événement window « declic:position ».
// État publié dans window.declicPositionEtat + événement « declic:position-etat » : "ok", "invite",
// "refuse" (permission bloquée) ou "echec" (position indisponible).
const CLE_REFUS = "declic:geoloc-refus"
const REFUS_MS = 7 * 24 * 60 * 60 * 1000
const DELAI_MS = 10000
const OPTIONS = { enableHighAccuracy: false, timeout: DELAI_MS, maximumAge: 10 * 60 * 1000 }

function refusMemorise() {
  try {
    const depuis = Number(localStorage.getItem(CLE_REFUS))
    return depuis > 0 && Date.now() - depuis < REFUS_MS
  } catch { return false } // stockage coupé : on redemande, sans bloquer
}

function memoriserRefus() {
  try { localStorage.setItem(CLE_REFUS, String(Date.now())) } catch { /* stockage indisponible */ }
}

function oublierRefus() {
  try { localStorage.removeItem(CLE_REFUS); localStorage.removeItem("declic:geoloc-auto") } catch { /* idem */ }
}

function publierEtat(etat) {
  window.declicPositionEtat = etat
  window.dispatchEvent(new CustomEvent("declic:position-etat", { detail: { etat } }))
}

async function etatPermission() {
  try {
    return navigator.permissions ? (await navigator.permissions.query({ name: "geolocation" })).state : null
  } catch { return null } // Permissions API absente ou sans « geolocation » (Safari ancien)
}

function utilisable() {
  return "geolocation" in navigator && window.isSecureContext
}

// Interroge le navigateur. `auto` : appel sans geste. `surEchec(code)` : prévient l'appelant (bouton « Me localiser »).
function interroger({ auto = false, surEchec } = {}) {
  let repondu = false
  const sansGeste = auto ? setTimeout(() => { if (!repondu) publierEtat("invite") }, DELAI_MS) : null
  navigator.geolocation.getCurrentPosition(
    ({ coords }) => {
      repondu = true
      clearTimeout(sansGeste)
      oublierRefus()
      window.declicPosition = { lat: coords.latitude, lon: coords.longitude }
      publierEtat("ok")
      window.dispatchEvent(new CustomEvent("declic:position", { detail: window.declicPosition }))
    },
    async (erreur) => {
      repondu = true
      clearTimeout(sansGeste)
      if (erreur.code === 1) { // refus (ou invite fermée) : ne pas redemander avant 7 jours
        memoriserRefus()
        publierEtat((await etatPermission()) === "denied" ? "refuse" : "ok-sans-position")
      } else {
        publierEtat("echec")
      }
      surEchec?.(erreur.code)
    },
    OPTIONS
  )
}

// Demande explicite (bouton « Me localiser », « Activer ma position ») : toujours permise, même après un refus mémorisé.
export function demander(surEchec) {
  if (!utilisable()) { publierEtat("echec"); surEchec?.(2); return }
  interroger({ surEchec })
}

async function demarrer() {
  if (!utilisable()) return
  const etat = await etatPermission()
  if (etat === "denied") { publierEtat("refuse"); return }
  if (etat === "granted") { interroger(); return }
  if (etat === null) { publierEtat("invite"); return } // pas d'API Permissions : un clic déclenchera l'invite
  if (refusMemorise()) return
  interroger({ auto: true })
}

demarrer()
