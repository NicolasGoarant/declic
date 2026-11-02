// Les dates des fiches. Le serveur les rend en ISO (AAAA-MM-JJ) ou nulles ; tout le reste
// compte comme « sans date ». Elles n'ont pas d'heure : on affiche une DATE, jamais « 00:00 ».
import { abregee, complete, jourMoisAbrege } from "dates_fr"

const JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const JOUR_MS = 86400000

// "2026-10-03" → Date locale à minuit, sinon null.
export function lireDate(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso ?? ""))
  if (!m) return null
  const d = new Date(+m[1], +m[2] - 1, +m[3])
  return d.getMonth() === +m[2] - 1 ? d : null
}

export function aujourdhui() {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  return d
}

const plusJours = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
const majuscule = (s) => s.charAt(0).toUpperCase() + s.slice(1)

// Dernier jour concerné : la fin, sinon le début.
export const dernierJour = (p) => p.fin || p.debut

export const estPasse = (p, jour = aujourdhui()) => Boolean(dernierJour(p)) && dernierJour(p) < jour
export const estAVenir = (p, jour = aujourdhui()) => Boolean(dernierJour(p)) && dernierJour(p) >= jour

// Chevauche [aujourd'hui, +1 jour) ou [aujourd'hui, +7 jours) : un événement en cours compte.
export function dansLaFenetre(p, quand, jour = aujourdhui()) {
  if (!p.debut) return false
  const fin = plusJours(jour, quand === "aujourdhui" ? 1 : 7)
  return p.debut < fin && dernierJour(p) >= jour
}

// Étiquette colorée de la fiche : « Aujourd'hui », « Demain », « Samedi », « Mer. 14 oct. 2026 » (place contrainte : abrégé).
export function etiquette(p, jour = aujourdhui()) {
  if (!p.debut) return null
  const debut = p.debut < jour ? jour : p.debut // en cours : on parle d'aujourd'hui
  const ecart = Math.round((debut - jour) / JOUR_MS)
  if (ecart === 0) return "Aujourd'hui"
  if (ecart === 1) return "Demain"
  if (ecart < 7) return majuscule(JOURS[debut.getDay()])
  return majuscule(abregee(debut))
}

export const jourCourt = jourMoisAbrege

// Ligne de résumé, format complet : « dimanche 1er novembre 2026 » ou « du samedi 3 au mardi 5 novembre 2026 »
// (l'année et le mois ne sont dits qu'une fois quand ils sont communs).
export function periode(p) {
  if (!p.debut) return null
  if (!p.fin || p.fin.getTime() === p.debut.getTime()) return complete(p.debut)
  const memeAnnee = p.debut.getFullYear() === p.fin.getFullYear()
  return `du ${complete(p.debut, !memeAnnee)} au ${complete(p.fin)}`
}
