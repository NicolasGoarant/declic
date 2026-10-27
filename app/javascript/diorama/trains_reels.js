// Les trains réels : traduit les passages du relais Rails (/trains/prochains.json : heures d'arrivée et de départ à
// Nancy-Ville, catégorie, côtés d'entrée et de sortie) en rames à jouer sur les itinéraires UNITAIRES de nancy-3d
// (itineraires-trains.json, une rame seule par itinéraire, parité avec la simulation vérifiée). Module sans DOM : il ne
// connaît que des heures (secondes Unix) et des descriptions de rame au format de `Rame` (trains.js).
//
// Une fiche = un passage, planifié une fois : itinéraire (donc voie à quai, NON publiée pour Nancy : choix plausible parmi
// les quais que la géométrie permet, un à la fois), heure d'apparition de la rame (`spawn`) et heure à laquelle elle a
// quitté la scène (`liberation`). Une fiche déjà lancée n'est plus modifiée ; avant, une nouvelle heure du relais la
// déplace sans changer de quai.

export const PREPARATION_DEPART_S = 75   // une rame qui part de Nancy est déjà à quai un peu avant l'heure
export const RESTE_TERMINUS_S = 150      // une rame qui termine à Nancy reste à quai, puis s'efface en fondu
export const FONDU_RETRAIT_S = 3
export const ARRET_MIN_S = 20            // arrêt à quai d'une rame qui continue : l'horaire borné
export const ARRET_MAX_S = 240
const MARGE_QUAI_S = 40                  // le quai est tenu un peu avant l'arrivée et après le départ
const SORTIE_QUAI_S = 30

// Catégorie commerciale du passage → type de rame du jeu (ter, tgv, tgv-duplex). Pas de sprite Intercités : rame TER.
export function typeDeRame(categorie, types) {
  const voulu = categorie === "tgv" ? "tgv" : "ter"
  return types.includes(voulu) ? voulu : "ter"
}

const hash = (s) => { let h = 0; for (const c of s) h = (h * 31 + c.charCodeAt(0)) | 0; return Math.abs(h) }
const borner = (x, a, b) => Math.min(b, Math.max(a, x))
const cleFamille = (entree, sortie) => entree && entree === sortie ? `${entree}>` : `${entree || ""}>${sortie || ""}`

export class Plan {
  // donnees : le contenu de itineraires-trains.json
  constructor(donnees) {
    this.params = donnees.parametres
    this.familles = new Map()
    for (const it of donnees.itineraires) {
      const cle = cleFamille(it.entree, it.sortie)
      if (!this.familles.has(cle)) this.familles.set(cle, [])
      this.familles.get(cle).push(it)
    }
    this.fiches = new Map()   // id du passage → fiche
  }

  // Les heures d'une fiche sur un itinéraire donné (A : arrivée, D : départ, secondes Unix)
  horaire(it, type, A, D) {
    const r = it.ref[type]
    if (it.nature === "arrivee") {
      return { spawn: A - r.t_arret_s, depart: null, arret: RESTE_TERMINUS_S, liberation: A + RESTE_TERMINUS_S + FONDU_RETRAIT_S,
               occupe: [A - MARGE_QUAI_S, A + RESTE_TERMINUS_S + FONDU_RETRAIT_S] }
    }
    if (it.nature === "traversee") {
      const arret = borner(D - A, ARRET_MIN_S, ARRET_MAX_S), apres = r.t_fin_s - r.t_arret_s - this.params.arret_ref_s
      return { spawn: A - r.t_arret_s, depart: A + arret, arret, liberation: A + arret + apres + 5, occupe: [A - MARGE_QUAI_S, A + arret + SORTIE_QUAI_S] }
    }
    const spawn = D - PREPARATION_DEPART_S
    return { spawn, depart: D, arret: 0, liberation: D + r.t_fin_s - this.params.depart_ref_s + 5, occupe: [spawn - 5, D + SORTIE_QUAI_S] }
  }

  occupation() {
    const occ = new Map()
    for (const f of this.fiches.values()) {
      if (!occ.has(f.it.quai)) occ.set(f.it.quai, [])
      occ.get(f.it.quai).push(f.h.occupe)
    }
    return occ
  }

  // Quai plausible : le premier libre dans un ordre qui tourne d'un passage à l'autre (pour ne pas tout mettre au quai 1)
  creer(p, occ) {
    const cands = this.familles.get(cleFamille(p.entree, p.sortie))
    if (!cands) return null
    const A = p.arrivee ?? p.depart, D = p.depart ?? p.arrivee
    const type0 = typeDeRame(p.categorie, cands.flatMap((i) => i.types))
    const ok = cands.filter((i) => i.types.includes(type0))
    const liste = ok.length ? ok : cands.filter((i) => i.types.includes("ter"))
    if (!liste.length) return null
    const type = ok.length ? type0 : "ter"
    const dec = hash(p.id) % liste.length
    let choix = null
    for (let k = 0; k < liste.length; k++) {
      const it = liste[(k + dec) % liste.length], h = this.horaire(it, type, A, D)
      const pris = (occ.get(it.quai) || []).some(([d, f]) => h.occupe[0] < f && d < h.occupe[1])
      if (!choix) choix = { it, h }
      if (!pris) { choix = { it, h }; break }
    }
    return { id: p.id, categorie: p.categorie, type, it: choix.it, h: choix.h, A, D, lancee: false }
  }

  // Intègre la dernière liste du relais (passages : objets du JSON)
  mettreAJour(passages, maintenant) {
    const presents = new Set(passages.map((p) => p.id))
    for (const [id, f] of this.fiches) {
      if (!presents.has(id) && (!f.lancee || f.h.liberation < maintenant - 60)) this.fiches.delete(id)
    }
    const nouveaux = []
    for (const p of passages) {
      const f = this.fiches.get(p.id)
      if (!f) { nouveaux.push(p); continue }
      if (f.lancee) continue
      const A = p.arrivee ?? p.depart, D = p.depart ?? p.arrivee
      Object.assign(f, { A, D, h: this.horaire(f.it, f.type, A, D) })
    }
    nouveaux.sort((u, v) => (u.arrivee ?? u.depart) - (v.arrivee ?? v.depart))
    for (const p of nouveaux) {
      const f = this.creer(p, this.occupation())
      if (f) this.fiches.set(p.id, f)
    }
  }

  // Un vrai train à jouer d'ici `avance` secondes (pas encore lancé) ?
  aJouer(maintenant, avance) {
    for (const f of this.fiches.values()) if (!f.lancee && f.h.spawn <= maintenant + avance && f.h.liberation > maintenant) return true
    return false
  }

  // Les fiches dont la rame doit entrer en scène à l'instant t (secondes Unix) ; celles déjà passées sont écartées
  dues(t) {
    const out = []
    for (const f of this.fiches.values()) {
      if (f.lancee || f.h.spawn > t) continue
      f.lancee = true
      if (f.h.liberation > t) out.push(f)
    }
    return out.sort((u, v) => u.h.spawn - v.h.spawn)
  }

  rearmer() { for (const f of this.fiches.values()) f.lancee = false }

  // La description d'une rame (format `Rame`) ; t0 : instant Unix du temps 0 de la scène
  description(f, t0) {
    const r = f.it.ref[f.type], depart = f.it.nature === "depart", terminus = f.it.nature === "arrivee"
    return { nom: f.id, type: f.type, morceaux: f.it.morceaux, s_tete: r.s_tete0, v0: depart ? 0 : this.params.v0_kmh / 3.6,
      arrets: depart ? [] : [[r.x_arret, f.h.arret]], depart_s: depart ? Math.max(0, f.h.depart - t0) : 0,
      sortie: !terminus, retrait: terminus ? FONDU_RETRAIT_S : 0 }
  }
}
