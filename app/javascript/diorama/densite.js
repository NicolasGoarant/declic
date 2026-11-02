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
