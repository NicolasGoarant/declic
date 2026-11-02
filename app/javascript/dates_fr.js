// Dates en français, écrites ici et nulle part ailleurs côté JS (le pendant Ruby : app/models/dates_fr.rb).
//   complete(d) → « dimanche 1er novembre 2026 »   abregee(d) → « dim. 1er nov. 2026 »
const JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const JOURS_ABREGES = ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
const MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
const MOIS_ABREGES = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

export const jourDuMois = (d) => (d.getDate() === 1 ? "1er" : String(d.getDate()))
export const complete = (d, annee = true) =>
  [JOURS[d.getDay()], jourDuMois(d), MOIS[d.getMonth()], annee ? d.getFullYear() : null].filter((x) => x !== null).join(" ")
export const abregee = (d, annee = true) =>
  [JOURS_ABREGES[d.getDay()], jourDuMois(d), MOIS_ABREGES[d.getMonth()], annee ? d.getFullYear() : null].filter((x) => x !== null).join(" ")
export const jourMoisAbrege = (d) => `${jourDuMois(d)} ${MOIS_ABREGES[d.getMonth()]}`
