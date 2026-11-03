// La météo réelle à Nancy pour le mode automatique : Open-Meteo (sans clé), code météo WMO courant
// traduit en clair, nuageux, brouillard, pluie ou neige. La réponse est gardée 30 minutes sur l'appareil
// (localStorage, try/catch) ; en cas d'échec (réseau, délai, réponse illisible) : clair, sans rien garder.
import { AUTO } from "diorama/reglages"
import { lire, ecrire } from "diorama/preferences"

const CLE = "declic:meteo-auto" // { meteo, code, le }

// Les météos connues, dans l'ordre du panneau.
export const METEOS = ["clair", "nuageux", "brouillard", "pluie", "neige"]

export function meteoDuCode(code) {
  if (AUTO.codes_neige.includes(code)) return "neige"
  if (AUTO.codes_pluie.includes(code)) return "pluie"
  if (AUTO.codes_brouillard.includes(code)) return "brouillard"
  if (AUTO.codes_nuageux.includes(code)) return "nuageux"
  return "clair"
}

// Ce que la météo fait au SOL (l'étalonnage d'ambiance, diorama/ambiance) : seules pluie et neige le touchent ;
// nuages et brouillard sont des toiles animées posées par-dessus (diorama/voiles), la dalle reste celle du ciel clair.
export function meteoDuSol(meteo) {
  return meteo === "pluie" || meteo === "neige" ? meteo : "clair"
}

// La météo gardée si elle a moins de 30 minutes, sinon null.
export function meteoGardee(maintenant = Date.now()) {
  try {
    const gardee = JSON.parse(lire(CLE))
    if (gardee && maintenant - gardee.le < AUTO.meteo_cache_min * 60000 && METEOS.includes(gardee.meteo)) return gardee.meteo
  } catch { /* illisible : on redemande */ }
  return null
}

let enCours = null

// Promesse de la météo courante (« clair » en cas d'échec) ; un seul appel à la fois.
export function meteoAuto() {
  const gardee = meteoGardee()
  if (gardee) return Promise.resolve(gardee)
  enCours ||= (async () => {
    const arret = new AbortController()
    const minuterie = setTimeout(() => arret.abort(), AUTO.meteo_delai_ms)
    try {
      const reponse = await fetch(AUTO.meteo_url, { signal: arret.signal })
      if (!reponse.ok) throw new Error(`HTTP ${reponse.status}`)
      const code = (await reponse.json())?.current?.weather_code
      if (!Number.isInteger(code)) throw new Error("code météo absent")
      const meteo = meteoDuCode(code)
      ecrire(CLE, JSON.stringify({ meteo, code, le: Date.now() }))
      return meteo
    } catch {
      return "clair" // repli silencieux : la carte ne dépend pas d'Open-Meteo
    } finally {
      clearTimeout(minuterie)
      enCours = null
    }
  })()
  return enCours
}
