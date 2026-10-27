// Les trains : rames TER et TGV qui roulent sur le réseau ferré de la maquette, par-dessus les dalles statiques.
// Portage de la simulation nancy-3d (rapports/animations-v1/trains-demo/animation/mouvement.py, nuit du 27/10/2026),
// réglages lus dans le jeu (reseau-trains.json, « reglages ») : rien n'est réglé ici. Jeu local « trains-v1 », PAS
// publié sur R2 (27/10/2026), PAS branché sur /labo/diorama : ce module n'est importé par aucune page.
//
// Données (format nancy-3d/reseau-trains v1, pixels de mosaïque au niveau 8) : arêtes des voies dessinées (px, sol en
// Lambert-93 moins `origine_l93`, vitesse limite déjà résolue), passages permis à chaque bout d'arête (précalculés),
// zones d'aiguille et d'engagement ; modèles et atlas des caisses (64 caps, ×4) et sa pyramide pré-réduite ; correctif
// d'occlusion des toits jv2 (occlusion-trains-jv2.json : dalles sol → volume, et dalles_vers_sol pour les abris de quai
// effacés du fond).
//
// Contrairement aux vivants, la position n'est PAS une fonction de l'heure : les rames ont un état (vitesse, cantons
// tenus) qui avance d'un pas fixe (`reglages.pas_s`, 0,5 s), comme la simulation de référence. Le module rejoue les
// trajectoires de scenarios-trains.json à 0,5 m près (test : ~/Documents/nancy-3d-trains-pilote/animation-v1/parite.mjs).
//
// MOUVEMENT (Rame.pas) : profil limite au mètre (vitesse de l'arête, du matériel, 40 km/h en déviation ; une limite vaut
// jusqu'à ce que la queue l'ait franchie), traction à puissance bornée, freinage de service, à-coup borné ; courbe de
// freinage vers chaque limite à venir et vers le point d'arrêt (fin d'autorisation ou arrêt en gare, a = v²/2d).
// CANTONS (Cantonnement) : coupés aux bords des zones et tous les 300 m ; accordés devant la rame (freinage + horizon),
// un aiguillage avec le canton libre qui le suit, une voie parcourue en sens inverse par une autre rame d'un bout à
// l'autre ; rendus quand la queue les a quittés. GARDE-FOU : deux rames dont les caisses se touchent au sol → la rame
// qui a bougé revient en arrière et s'arrête ; compté dans `stats.gardeFou` (doit rester à 0).
// OCCLUSION : la règle des colonnes des bateaux et des vivants, avec deux ajouts des trains (masquage-v1, 27/10) : les
// colonnes des faces d'extrémité suivent la colonne d'emprise la plus proche (BOUTS), et la décision de couper passe par
// un vote majoritaire sur VOTE_PX px n8 de colonnes (bord en escalier d'un abri). Les caisses sont des objets { Y, peindre }
// à trier AVEC les vivants (même règle : par Y d'ancre croissant) — voir `poserDans`.

const NIVEAU_REPERE = 8
const VOTE_PX = 7                   // nancy-3d, occlusion.py (pilote du 27/10)
const KMH = 1 / 3.6
// DÉCOR EN BOUCLE (page d'accueil) : les scénarios de démonstration se jouent l'un après l'autre jusqu'à la sortie de la
// dernière rame, puis la scène repart du début. Une rame entre et sort en fondu (à la sortie : sur les FONDU_SORTIE_M
// derniers mètres de la tête avant le bout du réseau), pour qu'aucune ne surgisse ni ne disparaisse d'un coup.
const FONDU_ENTREE_S = 2
const FONDU_SORTIE_M = 120
const FONDU_FIN_S = 2               // fondu général des rames restantes quand la scène est finie
const PAUSE_S = 3                   // scène vide entre deux scénarios
// Un scénario est fini quand toutes les rames ont quitté le réseau OU sont sorties de ZONE_DECOR (px n8, ≈ la vue initiale
// de l'accueil au niveau 6, autour de la gare) sans qu'aucune reste à entrer : sinon la scène resterait vide 2 à 3 minutes
// pendant que les dernières rames finissent leur trajet loin de l'écran.
const ZONE_DECOR = [14550, 8800, 19350, 12600]
const DUREE_MAX_S = 900             // garde-fou : un scénario qui ne se vide pas est repris au bout de 15 min
const RESEAU_N8 = [13300, 5800, 22700, 12400]   // emprise du réseau (px n8) : rien à lire ni à poser ailleurs
const NIVEAU_MIN = 6                // comme les vivants : plus petit, les rames ne sont plus qu'un trait
const STYLE_TRAINS = "jeu-video-v2" // la pose et le correctif d'occlusion valent pour ce fond seulement

const estVolume = (c) => c === 2 || c === 4

function lireJSON(u) {
  return fetch(u).then((r) => { if (!r.ok) throw new Error(`${u} : ${r.status}`); return r.json() })
}
function lireImage(u, croise) {
  return new Promise((ok, ko) => {
    const im = new Image()
    if (croise) im.crossOrigin = "anonymous"
    im.onload = () => ok(im); im.onerror = () => ko(new Error(u)); im.src = u
  })
}

// recherche du dernier indice i tel que t[i] ≤ x
function chercherIndice(t, x) {
  let a = 0, b = t.length - 1
  if (x <= t[0]) return 0
  if (x >= t[b]) return b
  while (b - a > 1) { const m = (a + b) >> 1; if (t[m] <= x) a = m; else b = m }
  return a
}

// ─── Le réseau ────────────────────────────────────────────────────────────────────────────────────────────────
export class Reseau {
  constructor(R, modeles) {
    this.R = R
    this.reg = R.reglages
    this.A = new Map()
    for (const a of R.aretes) this.A.set(a.id, a)
    this.passages = R.passages
    this.zonesParArete = new Map()
    this.nomsZones = new Map()
    for (const z of R.zones) {
      this.nomsZones.set(z.id, z.nom)
      for (const [k, iv] of Object.entries(z.aretes)) {
        const l = this.zonesParArete.get(+k) || []
        l.push([z.id, iv[0], iv[1]]); this.zonesParArete.set(+k, l)
      }
    }
    const E = R.camera.metre_est_px, N = R.camera.metre_nord_px
    this.M = [E[0], N[0], E[1], N[1]]                                  // sol (e, n) → px : [[Ex, Nx], [Ey, Ny]]
    const det = E[0] * N[1] - N[0] * E[1]
    this.Minv = [N[1] / det, -N[0] / det, -E[1] / det, E[0] / det]
    this.dim = new Map(modeles.modeles.map((m) => [m.cle, m]))
    this.rames = modeles.rames
  }

  lire(k, s, quoi) {
    const a = this.A.get(k), t = a.s, v = a[quoi]
    s = Math.min(Math.max(s, 0), a.L)
    const i = chercherIndice(t, s)
    if (i >= t.length - 1) return v[t.length - 1].slice()
    const u = (s - t[i]) / (t[i + 1] - t[i] || 1)
    return [v[i][0] + (v[i + 1][0] - v[i][0]) * u, v[i][1] + (v[i + 1][1] - v[i][1]) * u]
  }

  suivantes(k, sens) { return this.passages[`${k},${sens}`] || [] }

  zonesTouchees(intervalles) {
    const out = new Set()
    for (const [k, a, b] of intervalles) for (const [z, p, q] of this.zonesParArete.get(k) || []) if (a <= q && p <= b) out.add(z)
    return out
  }

  vitesseArete(k) { return this.A.get(k).vmax * KMH }

  composition(type) {
    const r = this.rames[type]
    return { caisses: r.caisses.map(([cle, ret]) => [cle, this.dim.get(cle).L, ret]), ecart: r.ecart_m, pivot: r.pivot_m }
  }

  longueurRame(type) {
    const c = this.composition(type)
    return c.caisses.reduce((t, x) => t + x[1], 0) + c.ecart * (c.caisses.length - 1)
  }

  capPx(dx, dy) {
    const m = this.Minv, e = m[0] * dx + m[1] * dy, n = m[2] * dx + m[3] * dy
    return ((Math.atan2(e, n) * 180 / Math.PI) % 360 + 360) % 360
  }

  // Caisses de la tête vers la queue : { cle, X, Y (ancre px n8), cap, capI, sol (4 coins au sol, m), coins (4 coins px n8) }
  poser(type, ch, sTete, caps = 64) {
    const c = this.composition(type), out = []
    let x = sTete
    for (const [cle, L, ret] of c.caisses) {
      const av = x - c.pivot, ar = x - (L - c.pivot)
      const pa = ch.point(av, "px"), pr = ch.point(ar, "px")
      let cap = this.capPx(pa[0] - pr[0], pa[1] - pr[1])
      if (ret) cap = (cap + 180) % 360
      const qa = ch.point(av, "e"), qr = ch.point(ar, "e")
      const ux = qa[0] - qr[0], uy = qa[1] - qr[1], l = Math.hypot(ux, uy) || 1e-9
      const W = this.dim.get(cle).W / 2, nx = -uy / l * W, ny = ux / l * W, hx = ux / l * L / 2, hy = uy / l * L / 2
      const mx = (qa[0] + qr[0]) / 2, my = (qa[1] + qr[1]) / 2
      const sol = [[mx + hx + nx, my + hy + ny], [mx - hx + nx, my - hy + ny], [mx - hx - nx, my - hy - ny], [mx + hx - nx, my + hy - ny]]
      const X = (pa[0] + pr[0]) / 2, Y = (pa[1] + pr[1]) / 2, M = this.M
      const coins = sol.map(([e, n]) => [X + M[0] * (e - mx) + M[1] * (n - my), Y + M[2] * (e - mx) + M[3] * (n - my)])
      out.push({ cle, X, Y, cap, capI: Math.round(cap / (360 / caps)) % caps, L, sol, coins })
      x -= L + c.ecart
    }
    return out
  }
}

// ─── Un chemin : morceaux [k, sens, s_a, s_b] parcourus dans l'ordre ───────────────────────────────────────────
export class Chemin {
  constructor(reseau, morceaux) {
    this.R = reseau
    this.morceaux = morceaux.filter((m) => Math.abs(m[3] - m[2]) > 1e-6)
    this.debuts = [0]
    for (const [, , a, b] of this.morceaux) this.debuts.push(this.debuts[this.debuts.length - 1] + Math.abs(b - a))
    this.longueur = this.debuts[this.debuts.length - 1]
  }

  localiser(x) {
    x = Math.min(Math.max(x, 0), this.longueur)
    let i = chercherIndice(this.debuts, x)
    i = Math.min(Math.max(i, 0), this.morceaux.length - 1)
    const [k, sens, a] = this.morceaux[i]
    return [k, a + sens * (x - this.debuts[i])]
  }

  point(x, quoi = "px") { const [k, s] = this.localiser(x); return this.R.lire(k, s, quoi) }

  intervalles(x0, x1) {
    const out = []
    this.morceaux.forEach(([k, sens, a, b], i) => {
      const d = this.debuts[i], l = Math.abs(b - a), u0 = Math.max(x0, d), u1 = Math.min(x1, d + l)
      if (u1 > u0) { const p = a + sens * (u0 - d), q = a + sens * (u1 - d); out.push([k, Math.min(p, q), Math.max(p, q)]) }
    })
    return out
  }
}

// ─── Profil limite ────────────────────────────────────────────────────────────────────────────────────────────
function deviations(R, ch) {
  const out = []
  for (let i = 0; i < ch.morceaux.length - 1; i++) {
    const [k, sens] = ch.morceaux[i], [k2, sens2] = ch.morceaux[i + 1], opts = R.suivantes(k, sens)
    if (opts.length >= 2) {
      const cmax = Math.max(...opts.map((o) => o[2]))
      const o = opts.find((o) => o[0] === k2 && o[1] === sens2), c = o ? o[2] : cmax
      if (c < cmax - 1e-3) out.push(ch.debuts[i + 1])
    }
  }
  return out
}

class Limites {
  constructor(R, ch, type) {
    const reg = R.reg, n = Math.ceil(ch.longueur) + 1, v = new Float64Array(n).fill(reg.materiel[type].vmax * KMH)
    ch.morceaux.forEach(([k, , a, b], i) => {
      const d = ch.debuts[i], i0 = Math.floor(d), i1 = Math.min(n - 1, Math.ceil(d + Math.abs(b - a))), w = R.vitesseArete(k)
      for (let j = i0; j <= i1; j++) if (w < v[j]) v[j] = w
    })
    this.deviees = deviations(R, ch)
    for (const d of this.deviees) {
      const i0 = Math.max(0, Math.trunc(d - reg.zone_deviee_m)), i1 = Math.min(n - 1, Math.trunc(d + reg.zone_deviee_m)), w = reg.deviee_kmh * KMH
      for (let j = i0; j <= i1; j++) if (w < v[j]) v[j] = w
    }
    this.v = v
  }

  sousLaRame(x, L) {
    const i0 = Math.max(0, Math.floor(x - L)), i1 = Math.min(this.v.length - 1, Math.ceil(x))
    let m = Infinity
    for (let i = i0; i <= i1; i++) if (this.v[i] < m) m = this.v[i]
    return m
  }
}

// ─── Cantons ──────────────────────────────────────────────────────────────────────────────────────────────────
let numeroCanton = 0
class Canton {
  constructor(ch, x0, x1, n) {
    this.x0 = x0; this.x1 = x1; this.n = n; this.id = ++numeroCanton
    this.intervalles = ch.intervalles(x0, x1)
    this.zones = ch.R.zonesTouchees(this.intervalles)
  }
}

function decouper(R, ch) {
  const coupes = [0]
  let avant = null
  for (let x = 0; x < ch.longueur; x += 1) {
    const dans = R.zonesTouchees(ch.intervalles(x, Math.min(x + 1, ch.longueur))).size > 0
    if (avant !== null && dans !== avant) coupes.push(x)
    avant = dans
  }
  coupes.push(ch.longueur)
  const bords = [coupes[0]]
  for (let i = 0; i < coupes.length - 1; i++) {
    const a = coupes[i], b = coupes[i + 1], m = Math.max(1, Math.round((b - a) / R.reg.canton_m))
    for (let j = 1; j <= m; j++) bords.push(a + (b - a) * j / m)
  }
  const out = []
  for (let i = 0; i < bords.length - 1; i++) if (bords[i + 1] - bords[i] > 1e-6) out.push(new Canton(ch, bords[i], bords[i + 1], out.length))
  return out
}

export class Cantonnement {
  constructor(R) { this.R = R; this.zones = new Map(); this.aretes = new Map(); this.journal = [] }

  libre(cantons, nom) {
    const marge = this.R.reg.marge_m
    for (const c of cantons) {
      for (const z of c.zones) {
        const t = this.zones.get(z)
        if (t) for (const n of t.keys()) if (n !== nom) return [false, `${this.R.nomsZones.get(z)} tenu par ${n}`]
      }
      for (const [k, a, b] of c.intervalles) {
        for (const [p, q, qui] of this.aretes.get(k) || []) {
          if (qui !== nom && a - marge <= q && p <= b + marge) return [false, `arête ${k} tenue par ${qui}`]
        }
      }
    }
    return [true, ""]
  }

  prendre(cantons, nom) {
    for (const c of cantons) {
      for (const z of c.zones) {
        if (!this.zones.has(z)) this.zones.set(z, new Map())
        const t = this.zones.get(z)
        if (!t.has(nom)) t.set(nom, new Set())
        t.get(nom).add(c.id)
      }
      for (const [k, a, b] of c.intervalles) {
        if (!this.aretes.has(k)) this.aretes.set(k, [])
        this.aretes.get(k).push([a, b, nom, c])
      }
    }
  }

  rendre(c, nom) {
    for (const z of c.zones) {
      const t = this.zones.get(z), s = t?.get(nom)
      if (s) { s.delete(c.id); if (!s.size) t.delete(nom) }
    }
    for (const [k] of c.intervalles) this.aretes.set(k, (this.aretes.get(k) || []).filter((e) => !(e[2] === nom && e[3] === c)))
  }
}

// Intervalles du chemin de r parcourus dans l'autre sens par une autre rame (ce qui reste sous elle et devant elle).
function sensInverse(r, autres) {
  const R = r.R, opp = new Map()
  for (const o of autres) {
    if (o.etat === "sortie") continue
    const x0 = o.x - o.L - R.reg.marge_m
    o.ch.morceaux.forEach(([k, sens, a, b], i) => {
      const d = o.ch.debuts[i], l = Math.abs(b - a)
      if (d + l <= x0) return
      const a2 = a + sens * Math.max(0, x0 - d)
      if (!opp.has(k)) opp.set(k, [])
      opp.get(k).push([sens, Math.min(a2, b), Math.max(a2, b)])
    })
  }
  const xs = []
  r.ch.morceaux.forEach(([k, sens, a, b], i) => {
    const d = r.ch.debuts[i]
    for (const [so, p, q] of opp.get(k) || []) {
      const lo = Math.max(Math.min(a, b), p), hi = Math.min(Math.max(a, b), q)
      if (so !== sens && hi > lo) { const u0 = d + (lo - a) * sens, u1 = d + (hi - a) * sens; xs.push([Math.min(u0, u1), Math.max(u0, u1)]) }
    }
  })
  xs.sort((u, v) => u[0] - v[0] || u[1] - v[1])
  const out = []
  for (const [p, q] of xs) {
    if (out.length && p <= out[out.length - 1][1] + R.reg.joint_m) out[out.length - 1][1] = Math.max(out[out.length - 1][1], q)
    else out.push([p, q])
  }
  return out
}

// ─── Une rame ─────────────────────────────────────────────────────────────────────────────────────────────────
export class Rame {
  // d : { nom, type, morceaux, s_tete, arrets [[x, attente_s]], depart_s, v0 (m/s), sortie } (scenarios-trains.json)
  constructor(R, d) {
    this.R = R; this.nom = d.nom; this.type = d.type
    this.ch = new Chemin(R, d.morceaux)
    this.x = d.s_tete; this.v = d.v0 || 0; this.a = 0
    this.xPrec = null   // x avant le dernier pas : l'image entre deux pas s'interpole (pas de 0,5 s = 2 positions par seconde sinon)
    this.L = R.longueurRame(d.type); this.m = R.reg.materiel[d.type]
    this.lim = new Limites(R, this.ch, d.type)
    this.cantons = decouper(R, this.ch)
    this.tenus = []; this.prochain = 0
    this.arrets = (d.arrets || []).map((a) => a.slice()).sort((u, v) => u[0] - v[0])
    this.departS = d.depart_s || 0
    this.sortie = d.sortie !== false
    this.attenteJusqua = null
    this.etat = this.departS > 0 ? "attente départ" : "marche"
    this.refus = null; this.partages = []; this.autres = []; this.present = false; this.tEntree = 0
  }

  finAutorisation() {
    if (!this.tenus.length) return this.x
    const fin = this.tenus[this.tenus.length - 1].x1
    if (fin >= this.ch.longueur - 1e-6) return this.sortie ? Infinity : fin
    return fin - this.R.reg.marge_signal_m
  }

  etendre(j) {
    const i = j, n = this.cantons.length
    this.partages = sensInverse(this, this.autres)
    for (;;) {
      const j0 = j
      while (j < n - 1 && this.cantons[j].zones.size) j++
      for (const [p, q] of this.partages) {
        if (this.cantons[i].x0 < q && p < this.cantons[j].x1 && this.cantons[j].x1 < q) while (j < n - 1 && this.cantons[j].x1 < q) j++
      }
      if (j === j0) return j
    }
  }

  demander(reg, t) {
    const R = this.R, b = this.m.b * R.reg.marge_plan
    const voulu = this.x + this.v ** 2 / (2 * b) + R.reg.horizon_m + R.reg.marge_signal_m
    while (this.prochain < this.cantons.length && (!this.tenus.length || this.tenus[this.tenus.length - 1].x1 < voulu)) {
      const j = this.etendre(this.prochain), lot = this.cantons.slice(this.prochain, j + 1)
      const [ok, motif] = reg.libre(lot, this.nom)
      if (!ok) {
        if (this.refus !== motif) reg.journal.push([t, this.nom, `attend : ${motif}`])
        this.refus = motif
        return
      }
      if (this.refus) reg.journal.push([t, this.nom, "voie libre"])
      this.refus = null
      reg.prendre(lot, this.nom)
      this.tenus.push(...lot)
      this.prochain = j + 1
    }
  }

  liberer(reg) {
    const queue = this.x - this.L - this.R.reg.marge_m
    while (this.tenus.length && this.tenus[0].x1 < queue) reg.rendre(this.tenus.shift(), this.nom)
  }

  prendreInitial(reg) {
    const marge = this.R.reg.marge_m, n = this.cantons.length
    let i = 0
    while (i < n && this.cantons[i].x1 < this.x - this.L - marge) i++
    let j = i
    while (j < n && this.cantons[j].x0 <= this.x + marge) j++
    j = j > i ? this.etendre(j - 1) + 1 : j
    const lot = this.cantons.slice(i, j), [ok, motif] = reg.libre(lot, this.nom)
    if (!ok) return motif
    reg.prendre(lot, this.nom)
    this.tenus = lot; this.prochain = j; this.present = true
    return null
  }

  vitessePermise(xArret) {
    const b = this.m.b * this.R.reg.marge_plan, lim = this.lim
    let v = lim.sousLaRame(this.x, this.L)
    const portee = this.x + (this.m.vmax * KMH) ** 2 / (2 * b) + 50
    const i0 = Math.ceil(this.x), i1 = Math.min(lim.v.length - 1, Math.trunc(portee))
    for (let i = i0; i <= i1 && i1 > i0; i++) { const w = Math.sqrt(lim.v[i] ** 2 + 2 * b * (i - this.x)); if (w < v) v = w }
    return Math.min(v, Math.sqrt(2 * b * Math.max(0, xArret - this.x)))
  }

  pas(dt, t, reg) {
    const R = this.R, m = this.m, jerk = R.reg.jerk, bPlan = m.b * R.reg.marge_plan
    if (this.etat === "attente départ") { if (t < this.departS) return; this.etat = "marche" }
    if (this.attenteJusqua !== null) {
      if (t < this.attenteJusqua) return
      this.attenteJusqua = null; this.arrets.shift(); this.etat = "marche"
      reg.journal.push([t, this.nom, "départ de l'arrêt"])
    }
    this.demander(reg, t)
    const xArret = Math.min(this.finAutorisation(), this.arrets.length ? this.arrets[0][0] : Infinity, this.sortie ? Infinity : this.ch.longueur)
    const vp = this.vitessePermise(xArret)
    let cible
    if (this.v < vp - 0.3) cible = Math.min(m.a0, m.P / Math.max(this.v, 0.1))
    else if (this.v > vp + 0.05) cible = -m.b
    else cible = 0
    const d = xArret - this.x
    if (this.v > 0.05 && d < Infinity) {
      const aReq = this.v ** 2 / (2 * Math.max(d, 0.05))
      if (aReq > 0.9 * bPlan) cible = Math.min(cible, -Math.min(aReq, m.b * 1.2))
    }
    this.a += Math.max(-jerk * dt, Math.min(jerk * dt, cible - this.a))
    if (cible < 0 && this.a > cible && d < Infinity && this.v ** 2 / (2 * Math.max(d, 0.05)) > -this.a + 0.05) this.a = cible
    let v1 = Math.max(0, this.v + this.a * dt), x1 = this.x + (this.v + v1) / 2 * dt
    if (v1 === 0 || (x1 >= xArret - 0.5 && v1 < 0.5)) { x1 = Math.max(this.x, Math.min(x1, xArret)); v1 = 0; this.a = 0 }
    this.x = Math.min(x1, this.ch.longueur); this.v = v1
    if (this.sortie && this.x >= this.ch.longueur - 1e-6) {
      for (const c of this.tenus) reg.rendre(c, this.nom)
      this.tenus = []; this.present = false; this.etat = "sortie"; this.prochain = this.cantons.length
      reg.journal.push([t, this.nom, "sort de scène"])
      return
    }
    if (this.v === 0 && this.arrets.length && Math.abs(this.x - this.arrets[0][0]) < 2 && this.attenteJusqua === null) {
      this.attenteJusqua = t + this.arrets[0][1]; this.etat = "à quai"
      reg.journal.push([t, this.nom, `arrêt en gare (${this.arrets[0][1]} s)`])
    } else if (this.v === 0 && this.x >= this.ch.longueur - 0.5) this.etat = "terminus"
    else if (this.v === 0 && this.refus) this.etat = "au signal"
    else if (this.etat !== "à quai") this.etat = "marche"
    this.liberer(reg)
  }

  // alpha = 1 : l'état du dernier pas ; sinon la position entre xPrec (alpha 0) et x (alpha 1)
  xA(alpha) { return alpha < 1 && this.xPrec !== null ? this.xPrec + (this.x - this.xPrec) * alpha : this.x }
  caisses(alpha = 1) { return this.R.poser(this.type, this.ch, this.xA(alpha)) }
}

// ─── Garde-fou : rectangles au sol (séparation des axes) ──────────────────────────────────────────────────────
function quadsSeTouchent(p, q) {
  for (const poly of [p, q]) {
    for (let i = 0; i < 4; i++) {
      const a = poly[i], b = poly[(i + 1) & 3], nx = a[1] - b[1], ny = b[0] - a[0]
      let pmin = Infinity, pmax = -Infinity, qmin = Infinity, qmax = -Infinity
      for (const c of p) { const s = c[0] * nx + c[1] * ny; pmin = Math.min(pmin, s); pmax = Math.max(pmax, s) }
      for (const c of q) { const s = c[0] * nx + c[1] * ny; qmin = Math.min(qmin, s); qmax = Math.max(qmax, s) }
      if (pmax < qmin || qmax < pmin) return false
    }
  }
  return true
}
const ramesSeTouchent = (ca, cb) => ca.some((a) => cb.some((b) => quadsSeTouchent(a.sol, b.sol)))

// ─── La scène : rames, cantonnement, horloge à pas fixe ───────────────────────────────────────────────────────
export class Scene {
  constructor(R, descriptions) {
    this.R = R; this.dt = R.reg.pas_s; this.t = 0; this.reg = new Cantonnement(R); this.gardeFou = []
    this.rames = descriptions.map((d) => new Rame(R, d))
    for (const r of this.rames) r.autres = this.rames.filter((o) => o !== r)
    for (const r of this.rames) { const motif = r.prendreInitial(this.reg); if (motif) this.reg.journal.push([0, r.nom, `entrée retardée : ${motif}`]); else r.tEntree = 0 }
  }

  pas() {
    const t = (this.t += this.dt)
    const prec = new Map()
    for (const r of this.rames) {
      if (!r.present) {
        if (r.etat !== "sortie" && r.prendreInitial(this.reg) === null) {
          r.demander(this.reg, t); r.v = Math.min(r.v, r.vitessePermise(r.finAutorisation())); r.tEntree = t
          this.reg.journal.push([t, r.nom, "entre en scène"])
        }
        continue
      }
      prec.set(r, r.x); r.xPrec = r.x
      r.pas(this.dt, t, this.reg)
    }
    const ici = this.rames.filter((r) => r.present), cais = new Map(ici.map((r) => [r, r.caisses()]))
    for (let i = 0; i < ici.length; i++) {
      for (let j = i + 1; j < ici.length; j++) {
        if (!ramesSeTouchent(cais.get(ici[i]), cais.get(ici[j]))) continue
        this.gardeFou.push([t, ici[i].nom, ici[j].nom])
        for (const r of [ici[i], ici[j]]) if (prec.has(r) && r.x !== prec.get(r)) { r.x = prec.get(r); r.v = 0; r.a = 0 }
      }
    }
  }

  // avance jusqu'à l'instant t (s) par pas fixes
  avancerJusqua(t) { while (this.t + this.dt <= t + 1e-9) this.pas() }

  // Pour le dessin : avance jusqu'au premier pas qui DÉPASSE t, puis rend alpha ∈ [0, 1], la part du dernier pas écoulée à
  // l'instant t (les rames se posent à xPrec + alpha (x − xPrec)). Même trajectoire que avancerJusqua, vue une demi-seconde
  // en retard au plus.
  jusqua(t) {
    while (this.t < t - 1e-9) this.pas()
    return Math.max(0, Math.min(1, (t - (this.t - this.dt)) / this.dt))
  }
}

// ─── Le dessin ────────────────────────────────────────────────────────────────────────────────────────────────
export class Trains {
  // options : dossier (URL du jeu trains-v1), scenario (nom dans scenarios-trains.json), propriete, dallesPropriete
  //           (comme Vivants), style (() → nom du style affiché : correctif jv2 seulement pour son style)
  //           scenarios (en boucle, à la place de `scenario`, voir `poserEnBoucle`) : liste de noms joués l'un après l'autre
  constructor({ dossier, scenario, scenarios = null, propriete, dallesPropriete, style = null }) {
    this.dossier = dossier.replace(/\/$/, "")
    this.nomScenario = scenario
    this.nomsBoucle = scenarios
    this.urlCode = propriete
    this.dallesCodes = dallesPropriete
    this.styleAffiche = style
    this.codes = new Map()
    this.stats = { rames: 0, caisses: 0, gardeFou: 0, js: 0 }
  }

  async charger() {
    const u = (n) => `${this.dossier}/${n}`
    const [R, modeles, sprites, atlas, reduitsS, reduitsA, scenarios, occlusion] = await Promise.all([
      lireJSON(u("reseau-trains.json")), lireJSON(u("modeles-trains.json")), lireJSON(u("sprites-trains.json")),
      lireImage(u("sprites-trains.png"), true), lireJSON(u("reduits/sprites.json")), lireImage(u("reduits/atlas.png"), true),
      lireJSON(u("scenarios-trains.json")), lireJSON(u("occlusion-trains-jv2.json")).catch(() => null)
    ])
    this.R = new Reseau(R, modeles)
    this.sprites = sprites; this.atlas = atlas; this.reduits = { S: reduitsS, atlas: reduitsA }
    this.occlusion = occlusion
    this.sequence = (this.nomsBoucle || [this.nomScenario]).map((n) => scenarios.scenarios[n])
    this.rang = 0
    this.scenario = this.sequence[0]
    this.recommencer()
    return this
  }

  recommencer() { this.scene = new Scene(this.R, this.scenario.rames) }

  // ─── codes de propriété (niveau 8) + correctif : volume → sol ET sol → volume ───────────────────────────────
  chargerCode(tx, ty) {
    const cle = tx * 4096 + ty
    if (this.codes.has(cle)) return
    const ent = { a: null }
    this.codes.set(cle, ent)
    if (!this.dallesCodes.has(`${tx}/${ty}`)) { ent.a = false; return }
    lireImage(this.urlCode(`${NIVEAU_REPERE}/${tx}/${ty}`), true).then((im) => {
      const cv = document.createElement("canvas"); cv.width = im.width; cv.height = im.height
      const c = cv.getContext("2d", { willReadFrequently: true }); c.drawImage(im, 0, 0)
      const px = c.getImageData(0, 0, im.width, im.height).data, a = new Uint8Array(im.width * im.height)
      for (let q = 0; q < a.length; q++) a[q] = px[4 * q]
      ent.brut = a; ent.w = im.width; ent.cle = `${tx}/${ty}`
      ent.a = this.codesDe(ent)
    }, () => { ent.a = false })
  }

  codesDe(ent) {
    const o = this.correctifActif() && this.occlusion
    const vol = o && o.dalles[ent.cle], sol = o && o.dalles_vers_sol?.[ent.cle]
    if (!vol && !sol) return ent.brut
    const a = ent.brut.slice()
    for (const [l, d, n] of vol || []) a.fill(2, l * ent.w + d, l * ent.w + d + n)
    for (const [l, d, n] of sol || []) a.fill(1, l * ent.w + d, l * ent.w + d + n)   // abris de quai effacés du fond
    return a
  }

  correctifActif() { return Boolean(this.occlusion) && (!this.occlusion.style || this.styleAffiche?.() === this.occlusion.style) }

  majStyle() { for (const ent of this.codes.values()) if (ent.brut) ent.a = this.codesDe(ent) }

  codeEn(nx, ny) {
    nx = Math.floor(nx); ny = Math.floor(ny)
    if (nx < 0 || ny < 0) return 0
    const tx = nx >> 8, ty = ny >> 8, d = this.codes.get(tx * 4096 + ty)
    if (!d) { this.chargerCode(tx, ty); return -1 }
    if (d.a === null) return -1
    if (d.a === false) return 0
    return d.a[(ny - (ty << 8)) * d.w + (nx - (tx << 8))]
  }

  // Le sprite : pyramide pré-réduite (le plus grand niveau dont l'échelle ne dépasse pas 2 × k × dpr), sinon l'atlas.
  spriteDe(c, k) {
    const n = this.reduits.S.niveaux[c.cle], cible = 2 * k * (window.devicePixelRatio || 1)
    if (n && this.sprites.echelles[c.cle] > cible) {
      let i = 0
      while (i < n.length - 1 && n[i][0] > cible) i++
      return { im: this.reduits.atlas, s: this.reduits.S.index[n[i][1]][c.capI], f: k / n[i][0] }
    }
    return { im: this.atlas, s: this.sprites.index[c.cle][c.capI], f: k / this.sprites.echelles[c.cle] }
  }

  // ─── l'occlusion d'une caisse : haut permis de chaque colonne CSS (null : rien à couper) ────────────────────
  // Règle des colonnes en px n8 (bas de l'emprise au sol, nappe de volume au-dessus), BOUTS bornés à l'emprise,
  // vote majoritaire sur VOTE_PX px n8 de colonnes ; la colonne coupée par le vote prend le haut de la plus proche.
  colonnes(sc, c, x0, w) {
    const xs = c.coins.map((p) => p[0]), xmin = Math.min(...xs) + 1e-3, xmax = Math.max(...xs) - 1e-3
    const haut = new Float64Array(w).fill(NaN), vue = new Uint8Array(w)
    for (let X = 0; X < w; X++) {
      const xc = Math.min(Math.max((x0 + X + 0.5 - sc.ox) / sc.k, xmin), xmax)
      let bas = -Infinity
      for (let e = 0; e < 4; e++) {
        const p = c.coins[e], q = c.coins[(e + 1) & 3]
        if ((p[0] - xc) * (q[0] - xc) > 0 || p[0] === q[0]) continue
        const yy = p[1] + (q[1] - p[1]) * (xc - p[0]) / (q[0] - p[0])
        if (yy > bas) bas = yy
      }
      if (bas === -Infinity) continue
      vue[X] = 1
      let ny = Math.floor(bas - 0.5)
      if (!estVolume(this.codeEn(xc, ny + 0.5))) continue
      const borne = ny - 200
      while (ny - 1 > borne && estVolume(this.codeEn(xc, ny - 0.5))) ny--
      haut[X] = ny * sc.k + sc.oy                      // px CSS
    }
    const r = Math.max(1, Math.round(VOTE_PX * sc.k / 2)), cs = new Int32Array(w + 1), vs = new Int32Array(w + 1)
    for (let X = 0; X < w; X++) { cs[X + 1] = cs[X] + (isNaN(haut[X]) ? 0 : 1); vs[X + 1] = vs[X] + vue[X] }
    const out = new Float64Array(w).fill(NaN)
    let une = false
    for (let X = 0; X < w; X++) {
      if (!vue[X]) continue
      const i = Math.max(0, X - r), j = Math.min(w, X + r + 1)
      if (2 * (cs[j] - cs[i]) <= vs[j] - vs[i]) continue
      if (!isNaN(haut[X])) out[X] = haut[X]
      else {
        let best = Infinity
        for (let Z = i; Z < j; Z++) if (!isNaN(haut[Z]) && Math.abs(Z - X) < Math.abs(best - X)) best = Z
        out[X] = haut[best]
      }
      une = true
    }
    return une ? out : null
  }

  peindre(ctx, sc, c) {
    const p = this.spriteDe(c, sc.k), s = p.s, f = p.f
    const X = c.X * sc.k + sc.ox, Y = c.Y * sc.k + sc.oy
    const x0 = Math.floor(X - s[4] * f), y0 = Math.floor(Y - s[5] * f), w = Math.ceil(s[2] * f) + 2, h = Math.ceil(s[3] * f) + 2
    const col = this.colonnes(sc, c, x0, w)
    if (col) {
      // rectangles permis : au-dessus du haut de nappe dans une colonne coupée, la colonne entière ailleurs
      ctx.save(); ctx.beginPath()
      let debut = 0, hc = isNaN(col[0]) ? y0 + h : col[0]
      for (let x = 1; x <= w; x++) {
        const hx = x === w ? NaN : isNaN(col[x]) ? y0 + h : col[x]
        if (x === w || hx !== hc) { if (hc > y0) ctx.rect(x0 + debut, y0, x - debut, hc - y0); debut = x; hc = hx }
      }
      ctx.clip()
    }
    if (c.alpha < 1) ctx.globalAlpha = c.alpha
    ctx.drawImage(p.im, s[0], s[1], s[2], s[3], X - s[4] * f, Y - s[5] * f, s[2] * f, s[3] * f)
    ctx.globalAlpha = 1
    if (col) ctx.restore()
  }

  // Avance la scène à l'instant t (s ; la scène reprend du début quand t revient en arrière) puis AJOUTE à `liste` les
  // caisses vues, objets { Y (px CSS), peindre(ctx) } triables avec ceux des vivants. La position est interpolée entre
  // deux pas de simulation (0,5 s). `plafond` : t ne dépasse pas la durée écrite du scénario (la démo) ; la boucle de
  // l'accueil le lève pour jouer le scénario jusqu'à la sortie de la dernière rame.
  poserDans(sc, t, liste, plafond = true, gain = 1) {
    const j0 = performance.now(), scene = this.scene
    if (t < scene.t - scene.dt - 1e-9) this.recommencer()   // le temps est revenu en arrière (la scène a un pas d'avance)
    const alpha = this.scene.jusqua(plafond ? Math.min(t, this.scenario.duree_s) : t), tRendu = this.scene.t - this.scene.dt + alpha * this.scene.dt
    let n = 0, rames = 0
    for (const r of this.scene.rames) {
      if (!r.present) continue
      rames++
      const dedans = Math.min(1, Math.max(0, (tRendu - r.tEntree) / FONDU_ENTREE_S))
      const dehors = r.sortie ? Math.min(1, Math.max(0, (r.ch.longueur - r.xA(alpha)) / FONDU_SORTIE_M)) : 1
      const fondu = dedans * dehors * gain
      if (fondu <= 0.01) continue
      for (const c of r.caisses(alpha)) {
        if (c.X < sc.xmin - 60 || c.X > sc.xmax + 60 || c.Y < sc.ymin - 60 || c.Y > sc.ymax + 60) continue
        c.alpha = fondu
        // Y en px n8 comme les vivants (o.Y est en px CSS chez eux, de même ordre : le tri ne dépend que de l'ordre)
        liste.push({ Y: c.Y * sc.k + sc.oy, peindre: (ctx) => this.peindre(ctx, sc, c) })
        n++
      }
    }
    this.stats = { rames, caisses: n, gardeFou: this.scene.gardeFou.length, js: performance.now() - j0 }
  }

  // Plus rien à voir : aucune rame à entrer, et celles qui restent sont hors de ZONE_DECOR (ou sorties)
  sceneFinie() {
    for (const r of this.scene.rames) {
      if (!r.present) { if (r.etat !== "sortie") return false; continue }
      const [X, Y] = r.ch.point(r.x, "px")
      if (X >= ZONE_DECOR[0] && X <= ZONE_DECOR[2] && Y >= ZONE_DECOR[1] && Y <= ZONE_DECOR[3]) return false
    }
    return true
  }

  // ─── Le décor en boucle (page d'accueil) ─────────────────────────────────────────────────────────────────────
  // À appeler à chaque image de la toile des vivants, avec l'horloge de la page (ms) : les scénarios se jouent l'un après
  // l'autre, chacun jusqu'à la sortie de sa dernière rame (ou DUREE_MAX_S), puis PAUSE_S de scène vide et le suivant.
  // L'horloge propre des trains n'avance que de 0,25 s au plus par image : un onglet resté caché ne fait pas rejouer
  // des minutes de simulation d'un coup. Rien tant que le fond n'est pas celui des trains, que la vue est petite ou
  // qu'elle ne recoupe pas le réseau ; les données (9 Mio) ne se lisent qu'à la première vue du réseau.
  poserEnBoucle(sc, ms, liste) {
    const delta = this.dernierMs == null ? 0 : Math.min(Math.max(ms - this.dernierMs, 0), 250) / 1000
    this.dernierMs = ms
    if (this.echec || this.styleAffiche?.() !== STYLE_TRAINS || sc.niveau < NIVEAU_MIN - 1e-9) return
    if (sc.xmax < RESEAU_N8[0] || sc.xmin > RESEAU_N8[2] || sc.ymax < RESEAU_N8[1] || sc.ymin > RESEAU_N8[3]) return
    if (!this.R) {
      this.promesse ??= this.charger().catch((e) => { console.warn("trains :", e); this.echec = true })
      return
    }
    if (this.pause > 0) {
      this.pause -= delta
      if (this.pause > 0) return
      this.pause = 0; this.fin = null
      this.rang = (this.rang + 1) % this.sequence.length
      this.scenario = this.sequence[this.rang]
      this.recommencer(); this.tScene = 0
    }
    this.tScene = (this.tScene || 0) + delta
    const gain = this.fin == null ? 1 : Math.max(0, 1 - (this.tScene - this.fin) / FONDU_FIN_S)
    if (gain > 0) this.poserDans(sc, this.tScene, liste, false, gain)
    else this.pause = PAUSE_S
    if (this.fin == null && (this.scene.t > DUREE_MAX_S || this.sceneFinie())) this.fin = this.tScene
  }
}
