// Les choix de carte gardés sur l'appareil (localStorage). Stockage indisponible (navigation privée,
// données bloquées) : on lit null et on n'écrit rien, la carte garde ses réglages par défaut.
export const CLE_FOND = "declic:fond"               // "diorama" | "plan"
export const CLE_BLANCHE = "declic:maquette-blanche" // "1" | "0"
// Ambiance : trois réglages indépendants et l'interrupteur « Automatique ».
export const CLE_AUTO = "declic:ambiance-auto"      // "1" | "0" ; absente : automatique (voir diorama#lireReglages)
export const CLES_REGLAGES = { moment: "declic:moment", saison: "declic:saison", meteo: "declic:meteo" }
export const CLE_AMBIANCE = "declic:ambiance"       // ancienne clé (une seule ambiance), lue une fois pour reprise
export const CLE_STYLE = "declic:style"             // "jeu-video-v2" | "toits-v1"
const STYLE_DEFAUT = "jeu-video-v2"

export function lire(cle) {
  try { return localStorage.getItem(cle) } catch { return null }
}

export function ecrire(cle, valeur) {
  try { localStorage.setItem(cle, valeur) } catch { /* stockage indisponible */ }
}

// Le fond au démarrage : le choix mémorisé, sinon le plan si l'appareil économise les données
// (navigator.connection.saveData), sinon le diorama.
export function fondDeDepart() {
  const memorise = lire(CLE_FOND)
  if (memorise === "diorama" || memorise === "plan") return memorise
  return navigator.connection?.saveData ? "plan" : "diorama"
}

// Le style du diorama au démarrage : le choix mémorisé s'il est encore publié, sinon le style par
// défaut (Jeu vidéo) s'il l'est, sinon le premier style publié.
export function styleDeDepart(disponibles) {
  const memorise = lire(CLE_STYLE)
  if (memorise && disponibles.includes(memorise)) return memorise
  return disponibles.includes(STYLE_DEFAUT) ? STYLE_DEFAUT : disponibles[0]
}
