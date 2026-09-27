// La météo réelle à Nancy pour le mode automatique : Open-Meteo (sans clé), code météo WMO courant
// traduit en clair, pluie ou neige. La réponse est gardée 30 minutes sur l'appareil (localStorage,
// try/catch) ; en cas d'échec (réseau, délai, réponse illisible) : clair, sans rien garder.
import { AUTO } from "diorama/reglages"
import { lire, ecrire } from "diorama/preferences"

const CLE = "declic:meteo-auto" // { meteo, code, le }

export function meteoDuCode(code) {
  if (AUTO.codes_neige.includes(code)) return "neige"
  if (AUTO.codes_pluie.includes(code)) return "pluie"
  return "clair"
}

// La météo gardée si elle a moins de 30 minutes, sinon null.
export function meteoGardee(maintenant = Date.now()) {
  try {
    const gardee = JSON.parse(lire(CLE))
    if (gardee && maintenant - gardee.le < AUTO.meteo_cache_min * 60000 && ["clair", "pluie", "neige"].includes(gardee.meteo)) return gardee.meteo
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
