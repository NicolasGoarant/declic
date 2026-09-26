// Le mode automatique des ambiances, porté de maquette-declic-v3 : l'heure bleue passe devant
// la saison, et hors de ces fenêtres c'est l'origine.
//
// Saisons en « mois-jour », bornes comprises ; une saison qui enjambe le 1er janvier se
// déclare telle quelle (début après fin).
const AUTOMNE = ["09-22", "11-30"]
const HIVER = ["12-01", "02-29"]
// L'heure bleue va du coucher (centre du disque à −0,833°) à la nuit (fin du crépuscule
// civil, −6°), le soir seulement.
const NANCY_LAT = 48.6937, NANCY_LON = 6.1834
const HAUTEUR_COUCHER_DEG = -0.833, HAUTEUR_NUIT_DEG = -6.0

// Hauteur du soleil à Nancy, formules de la NOAA (Meeus simplifié), sans service externe.
// Rend la hauteur géométrique en degrés et l'angle horaire (> 0 le soir).
export function soleil(date) {
  const rad = Math.PI / 180, jd = date.getTime() / 86400000 + 2440587.5, T = (jd - 2451545) / 36525
  const L0 = ((280.46646 + T * (36000.76983 + T * 0.0003032)) % 360 + 360) % 360
  const M = 357.52911 + T * (35999.05029 - 0.0001537 * T)
  const e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
  const C = Math.sin(M * rad) * (1.914602 - T * (0.004817 + 0.000014 * T)) +
            Math.sin(2 * M * rad) * (0.019993 - 0.000101 * T) + Math.sin(3 * M * rad) * 0.000289
  const omega = 125.04 - 1934.136 * T
  const lambda = L0 + C - 0.00569 - 0.00478 * Math.sin(omega * rad)
  const eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
  const eps = eps0 + 0.00256 * Math.cos(omega * rad)
  const decl = Math.asin(Math.sin(eps * rad) * Math.sin(lambda * rad))
  const y = Math.pow(Math.tan(eps * rad / 2), 2)
  const eqt = 4 / rad * (y * Math.sin(2 * L0 * rad) - 2 * e * Math.sin(M * rad) +
              4 * e * y * Math.sin(M * rad) * Math.cos(2 * L0 * rad) -
              0.5 * y * y * Math.sin(4 * L0 * rad) - 1.25 * e * e * Math.sin(2 * M * rad))
  const minutesUtc = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60
  const tst = ((minutesUtc + eqt + 4 * NANCY_LON) % 1440 + 1440) % 1440
  const ah = tst / 4 - 180
  const cz = Math.sin(NANCY_LAT * rad) * Math.sin(decl) + Math.cos(NANCY_LAT * rad) * Math.cos(decl) * Math.cos(ah * rad)
  return { hauteur: 90 - Math.acos(Math.max(-1, Math.min(1, cz))) / rad, angleHoraire: ah }
}

// Coucher et nuit du jour local de `date`, à la minute près, par balayage depuis midi.
function fenetreDuSoir(date) {
  const midi = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12, 0, 0)
  const r = { coucher: null, nuit: null }
  for (let m = 0; m < 720 && !r.nuit; m++) {
    const t = new Date(midi.getTime() + m * 60000), s = soleil(t)
    if (s.angleHoraire <= 0) continue
    if (!r.coucher && s.hauteur < HAUTEUR_COUCHER_DEG) r.coucher = t
    if (!r.nuit && s.hauteur < HAUTEUR_NUIT_DEG) r.nuit = t
  }
  return r
}

const dansSaison = (md, [debut, fin]) => debut <= fin ? (md >= debut && md <= fin) : (md >= debut || md <= fin)

// Nom de l'ambiance que le mode automatique retient pour `date`.
export function resoudreAuto(date = new Date()) {
  const { coucher, nuit } = fenetreDuSoir(date)
  const md = `${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`
  if (coucher && nuit && date >= coucher && date < nuit) return "heure-bleue"
  if (dansSaison(md, HIVER)) return "hiver"
  if (dansSaison(md, AUTOMNE)) return "automne"
  return "origine"
}
