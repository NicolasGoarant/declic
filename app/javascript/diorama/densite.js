// Densité de pixels des toiles ANIMÉES (vivants, mobiles, trains) : plafonnée à 1,5.
// À dpr 2 une toile de la taille de la carte pèse 4 × les pixels d'un écran standard et se repeint jusqu'à 30 fois
// par seconde ; à 1,5 (2,25 ×) les sprites restent nets pour des objets de quelques pixels. Sous 1,5, rien ne change.
export const DPR_MAX_TOILES = 1.5

export function dprToiles() {
  return Math.min(window.devicePixelRatio || 1, DPR_MAX_TOILES)
}

// Rythmes de repeinte des toiles animées : 30 images/s au repos, 12 pendant un geste de carte (déplacement, zoom).
export const INTERVALLE_REPOS_MS = 1000 / 30 - 2
export const INTERVALLE_GESTE_MS = 1000 / 12 - 2

// Cadence adaptative : une repeinte qui coûte plus de la moitié de l'intervalle (poste modeste) espace les suivantes,
// pour laisser au navigateur de quoi défiler et répondre. Lissage de la durée mesurée ; jamais en dessous de 8 images/s.
export const INTERVALLE_MAX_MS = 125

export function lisserCout(cout, mesure) {
  return cout ? 0.8 * cout + 0.2 * mesure : mesure
}

export function intervalleAdapte(base, cout) {
  return Math.min(INTERVALLE_MAX_MS, Math.max(base, 2 * (cout || 0)))
}
