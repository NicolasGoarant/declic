// Les vivants : vélos, piétons, voitures, bus et trolleybus animés, posés SUR la maquette, par-dessus les dalles statiques.
// Portage du prototype nancy-3d (rapports/animations-v1/vivants-demo/index.html, commit ddc2ae8 du 20/10/2026),
// réglages repris TELS QUELS : rien n'est réglé ici. Données : calques des réseaux (format nancy-3d/calque-vivant,
// pixels de mosaïque au niveau 8, itinéraires raccordés aux carrefours), atlas des sprites cuits pour la caméra du
// diorama et sa pyramide pré-réduite, modèles, repère de la caméra. Le jeu n'est PAS publié sur R2 (20/10/2026) :
// la page le lit à l'adresse que lui donne DIORAMA_VIVANTS_URL.
//
// Bus et trolleybus (21/10/2026, démo nancy-3d 78546f1, diagnostics § 16) : lus SEULEMENT si le jeu en porte les modèles
// (vivants-v2 et suivants) ; vivants-v1, qui n'en a pas, ne demande ni bus.json ni trolleybus.json et rend la même image.
// Un bus suit la fréquence de sa ligne (itineraires_bus_par_heure du calque, variantes d'une ligne partagées), pas une
// densité ; arrêts non marqués (décidé, § 16.2).
//
// Laissé de côté : le correctif d'occlusion des toits jv2 (occlusion-toits-jv2.json), qui ne vaut que pour le style
// jeu-video-v2.
//
// Une toile À PART, posée sur celle des dalles (pointer-events: none) : le chargement et le dessin des dalles ne
// changent pas. Elle suit la vue de la page (cx, cy, s) à chaque image.
//
// Ce que fait chaque image (rien n'est gardé d'une image à l'autre : la position est une fonction de l'heure) :
//   1. la POSE : sur chaque segment d'itinéraire vu, les mobiles dont le temps de parcours y tombe ;
//   2. la PEINTURE, du plus loin au plus près, chaque objet DÉCOUPÉ colonne par colonne par les volumes de la
//      carte de propriété (propriete-toits-v1) qui le couvrent.
//
// Sobriété : 30 images par seconde au plus quand la vue ne bouge pas, animation suspendue quand l'onglet est
// caché, et rien si l'appareil demande moins d'animations (prefers-reduced-motion).
//
// Crochets d'instrument, déclarés (ils ne changent rien quand on ne les demande pas) :
//   ?vivants-t=S                fige l'horloge à S secondes (captures comparables)
//   ?vivants-densite-velo=P,B   vélos par km et par sens, piste et bande (témoin : 16,12, la densité d'avant ×5)
//   ?vivants-bus=0              ni bus ni trolleybus, même si le jeu en porte (témoin : la page d'avant le 21/10)

const NIVEAU_REPERE = 8
const MOINS_DE_MOUVEMENT = "(prefers-reduced-motion: reduce)"
const INTERVALLE_MS = 1000 / 30 - 2
const ECHELLE_VIVANTS = 1.6         // DÉCIDÉ le 17/10 (diagnostics § 8) : gain minimal des piétons, voitures et vélos
const MODELE_VELO = "velo-detaille" // 20/10
// Par type : plancher en px CSS (longueur d'un véhicule, hauteur d'une personne), gain maximal sur la taille réelle,
// niveau en dessous duquel on ne dessine rien. Voiture 10 px g ≤ 1,5 et piéton 8 px g ≤ 2 DÉCIDÉS le 16/10 (§ 6) ;
// vélo 10 px g ≤ 2,4 DÉCIDÉ le 20/10 (§ 12). Piétons et vélos dès ×0,5 comme les voitures (20/10, Nicolas) : sous
// `tailleFigee` (×1), ils gardent la taille à l'écran jugée à ×1 (piéton 6,1 px, vélo 9,8 px) au lieu de rétrécir.
// Bus et trolleybus 24 px g ≤ 1,25, échelle ×1,25 (et non ×1,6) : DÉCIDÉS le 19/10 (§ 9-10).
// Toutes les familles dès ×0,25 (niveau 6, 21/10, Nicolas) : sous ×0,5, voitures, bus et trolleybus gardent leur taille
// à l'écran de ×0,5 (`tailleFigee` 7), comme piétons et vélos gardent celle de ×1 ; ×0,5 à ×2 inchangés.
const PLANCHER = {
  voiture: { px: 10, gain: 1.5, niveauMin: 6, tailleFigee: 7, mesure: "L" },
  bus: { px: 24, gain: 1.25, niveauMin: 6, tailleFigee: 7, mesure: "L", echelle: 1.25 },
  trolleybus: { px: 24, gain: 1.25, niveauMin: 6, tailleFigee: 7, mesure: "L", echelle: 1.25 },
  velo: { px: 10, gain: 2.4, niveauMin: 6, tailleFigee: 8, mesure: "L" },
  pieton: { px: 8, gain: 2, niveauMin: 6, tailleFigee: 8, mesure: "H" }
}
const VITESSE_VEH = [25, 13, 11, 9, 7, 4]   // m/s par classe : autoroute … partagée
const DENSITE_VEH = [12, 14, 12, 9, 5, 2]   // par km et par file
const DENSITE_PIE = [30, 30, 40, 15, 20]    // par km et par sens : trottoir, passage, piéton, escalier, bord
const VITESSE_VELO = [4, 5]                 // m/s, bornes du tirage par itinéraire
const DENSITE_VELO = [20, 15]               // par km et par sens, piste et bande : ×5, 20/10 au soir (§ 15)
const VITESSE_BUS = [7, 8]                  // m/s : chaussée, voie réservée (bus et trolleybus)
const MODELES_BUS = { bus: "bus-detaille-v2", trolleybus: "trolleybus-tempo1-v2" } // 20/10
// le type de modèle (et de plancher) de chaque calque
const TYPE_CALQUE = { vehicules: "voiture", pietons: "pieton", velos: "velo", bus: "bus", trolleybus: "trolleybus" }
const FONDU_M = 10                          // un mobile s'efface sur ses 10 derniers mètres avant un bout
const MARGE_VUS = 0.5                       // les segments vus couvrent la vue élargie de moitié de chaque côté

function graineDe(i, j, k) {
  let h = (i * 374761393 + j * 668265263 + k * 2246822519) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}
const replier = (a, b) => ((a % b) + b) % b
const estVolume = (c) => c === 2 || c === 4 // propriété : 1 sol posé, 2 volume posé, 3 sol repris, 4 volume repris
const typeDe = (M) => (M.type in PLANCHER ? M.type : "voiture")

function lireJSON(u) {
  return fetch(u).then((r) => { if (!r.ok) throw new Error(`${u} : ${r.status}`); return r.json() })
}
function lireImage(u, croise) {
  return new Promise((ok, ko) => {
    const im = new Image()
    if (croise) im.crossOrigin = "anonymous"
    im.onload = () => ok(im)
    im.onerror = () => ko(new Error(u))
    im.src = u
  })
}

export class Vivants {
  // options : dossier (URL du jeu), propriete (chemin "8/x/y" → URL de la dalle de codes),
  //           dallesPropriete (Set("x/y") des dalles publiées au niveau 8 ; une absente vaut « dehors »),
  //           vue (() → { cx, cy, s, W, H } : centre en px de mosaïque L8, px CSS par px de mosaïque, taille CSS),
  //           ancre (la toile des dalles : celle des vivants est posée juste après, sous le reste de la page)
  constructor({ dossier, propriete, dallesPropriete, vue, ancre }) {
    this.dossier = dossier.replace(/\/$/, "")
    this.urlCode = propriete
    this.dallesCodes = dallesPropriete
    this.vue = vue
    this.ancre = ancre
    this.codes = new Map()
    const params = new URLSearchParams(location.search)
    this.horlogeFigee = params.has("vivants-t") ? parseFloat(params.get("vivants-t")) : null
    this.densiteVelo = params.has("vivants-densite-velo") ? params.get("vivants-densite-velo").split(",").map(parseFloat) : DENSITE_VELO
    this.sansBus = params.get("vivants-bus") === "0"
    this.stats = { pietons: 0, voitures: 0, velos: 0, bus: 0, trolleybus: 0, js: 0, niveau: null }
    this.t0 = performance.now()
    this.actif = false
  }

  horloge() { return this.horlogeFigee ?? (performance.now() - this.t0) / 1000 }

  async charger() {
    const f = (n) => `${this.dossier}/${n}`
    const [veh, pie, velo, rep, modeles, sprites, atlas, reduitsS, reduitsA] = await Promise.all([
      lireJSON(f("vehicules.json")), lireJSON(f("pietons.json")), lireJSON(f("velos.json")), lireJSON(f("repere.json")),
      lireJSON(f("modeles-vivants.json")), lireJSON(f("sprites-vivants.json")), lireImage(f("sprites-vivants.png"), true),
      lireJSON(f("reduits/sprites.json")), lireImage(f("reduits/atlas.png"), true)
    ])
    // bus et trolleybus : seulement si le jeu en porte les modèles (vivants-v1 n'en a pas : aucune requête de plus)
    const lignes = this.sansBus ? [] : ["bus", "trolleybus"].filter((t) => modeles.modeles.some((m) => m.cle === MODELES_BUS[t]))
    const calquesLignes = await Promise.all(lignes.map((t) => lireJSON(f(`${t}.json`))))
    this.rep = rep
    this.sprites = sprites
    this.atlas = atlas
    this.reduits = { S: reduitsS, atlas: reduitsA }
    const E = rep.metre_est_px, N = rep.metre_nord_px, det = E[0] * N[1] - N[0] * E[1]
    this.inv = [N[1] / det, -N[0] / det, -E[1] / det, E[0] / det] // px L8 → mètres (E, N) au sol
    this.parType = {}
    for (const m of modeles.modeles) {
      if ((m.type === "pieton" && m.pose < 0) || (m.type === "velo" && m.cle !== MODELE_VELO) ||
          (m.type in MODELES_BUS && m.cle !== MODELES_BUS[m.type])) continue
      ;(this.parType[m.type] ||= []).push(m)
    }
    this.calques = [
      this.preparerCalque(veh, "vehicules"), this.preparerCalque(pie, "pietons"), this.preparerCalque(velo, "velos"),
      ...lignes.map((t, i) => this.preparerCalque(calquesLignes[i], t))
    ]
    this.aBus = lignes.length > 0
  }

  // ─── Les calques ──────────────────────────────────────────────────────────────────────────────────────────
  // Un calque : ses morceaux vus (rangés par voie) et ses itinéraires.
  preparerCalque(C, nom) {
    const K = { nom, type: TYPE_CALQUE[nom], voies: C.voies, mq: [], parVoie: {}, boiteVoie: {}, frequences: C.itineraires_bus_par_heure }
    const inv = this.inv
    C.liste.forEach((M, i) => {
      const c = M[3], n = c.length / 2, cum = new Float64Array(n), dirs = new Float64Array(2 * n)
      let s = 0, x0 = c[0], y0 = c[1], x1 = c[0], y1 = c[1]
      for (let j = 1; j < n; j++) {
        const dx = c[2 * j] - c[2 * j - 2], dy = c[2 * j + 1] - c[2 * j - 1]
        const gE = inv[0] * dx + inv[1] * dy, gN = inv[2] * dx + inv[3] * dy, lm = Math.sqrt(gE * gE + gN * gN)
        s += lm; cum[j] = s
        dirs[2 * (j - 1)] = lm > 0 ? gE / lm : 1; dirs[2 * (j - 1) + 1] = lm > 0 ? gN / lm : 0
        x0 = Math.min(x0, c[2 * j]); x1 = Math.max(x1, c[2 * j]); y0 = Math.min(y0, c[2 * j + 1]); y1 = Math.max(y1, c[2 * j + 1])
      }
      if (n > 1) { dirs[2 * (n - 1)] = dirs[2 * (n - 2)]; dirs[2 * (n - 1) + 1] = dirs[2 * (n - 2) + 1] }
      K.mq.push({ s0: M[1], s1: M[2], c, cum, dirs, L: s })
      ;(K.parVoie[M[0]] ||= []).push(i)
      const b = K.boiteVoie[M[0]]
      K.boiteVoie[M[0]] = b ? [Math.min(b[0], x0), Math.min(b[1], y0), Math.max(b[2], x1), Math.max(b[3], y1)] : [x0, y0, x1, y1]
    })
    for (const v in K.parVoie) K.parVoie[v].sort((a, b) => K.mq[a].s0 - K.mq[b].s0)
    K.its = C.itineraires.map((it) => {
      const boucle = it.length > 0 && !Array.isArray(it[it.length - 1])
      return { segs: boucle ? it.slice(0, -1) : it, boucle }
    })
    this.preparerParcours(K)
    return K
  }

  // Pour chaque itinéraire : longueurs et temps cumulés, flux (mobiles par seconde). Bus et trolleybus : le flux est la
  // fréquence de la ligne (bus/h ÷ 3 600), pas une densité.
  preparerParcours(K) {
    const pie = K.nom === "pietons", velo = K.nom === "velos", bus = !!K.frequences
    K.its.forEach((it, ii) => {
      const n = it.segs.length, C = new Float64Array(n + 1), T = new Float64Array(n + 1), vit = new Float64Array(n)
      const vPieton = 1.1 + 0.4 * graineDe(ii, 7, 3), vVelo = VITESSE_VELO[0] + (VITESSE_VELO[1] - VITESSE_VELO[0]) * graineDe(ii, 7, 4)
      let flux = 0
      for (let j = 0; j < n; j++) {
        const sg = it.segs[j], l = Math.abs(sg[2] - sg[1]), cl = K.voies[sg[0]][0]
        vit[j] = pie ? vPieton : velo ? vVelo : bus ? VITESSE_BUS[cl] : VITESSE_VEH[cl]
        flux += (pie ? DENSITE_PIE[cl] : velo ? this.densiteVelo[cl] : bus ? 0 : DENSITE_VEH[cl]) / 1000 * vit[j] * l
        C[j + 1] = C[j] + l; T[j + 1] = T[j] + l / vit[j]
      }
      Object.assign(it, { C, T, vit, L: C[n], id: ii, phase: graineDe(ii, 11, 5) })
      it.flux = bus ? K.frequences[ii] / 3600 : it.L > 0 ? flux / it.L : 0 // sinon : moyenne des flux de classe, pondérée par la longueur
    })
  }

  // La position au sol d'une abscisse s (m) de la voie iv : [x, y px L8, gE, gN] dans le sens du tracé, ou null si
  // cette abscisse tombe là où la voie ne se voit pas.
  situer(K, iv, s) {
    const mq = K.parVoie[iv]
    if (!mq) return null
    let lo = 0, hi = mq.length - 1, i = -1
    while (lo <= hi) {
      const mi = (lo + hi) >> 1, M = K.mq[mq[mi]]
      if (s < M.s0) hi = mi - 1; else if (s > M.s1) lo = mi + 1; else { i = mq[mi]; break }
    }
    if (i < 0) return null
    const { c, cum, dirs, s0, s1, L } = K.mq[i], et = s1 - s0, u = et > 0 ? (s - s0) / et * L : 0
    lo = 0; hi = cum.length - 1
    while (hi - lo > 1) { const m = (lo + hi) >> 1; if (cum[m] <= u) lo = m; else hi = m }
    const seg = cum[hi] - cum[lo], f = seg > 0 ? (u - cum[lo]) / seg : 0
    return [c[2 * lo] + f * (c[2 * hi] - c[2 * lo]), c[2 * lo + 1] + f * (c[2 * hi + 1] - c[2 * lo + 1]), dirs[2 * lo], dirs[2 * lo + 1]]
  }

  // Les segments d'itinéraire dont la voie croise la boîte [x0, y0, x1, y1] (px L8).
  segmentsVus(K, boite) {
    const r = [], [bx0, by0, bx1, by1] = boite
    K.its.forEach((it, ii) => {
      for (let j = 0; j < it.segs.length; j++) {
        const b = K.boiteVoie[it.segs[j][0]]
        if (!b || b[2] < bx0 || b[0] > bx1 || b[3] < by0 || b[1] > by1) continue
        r.push(ii, j)
      }
    })
    return r
  }

  // Recalculés quand la vue sort de la boîte élargie du dernier calcul (la démo : à chaque fin de déplacement).
  majVus(sc) {
    const b = this.vus?.boite
    if (b && sc.xmin >= b[0] && sc.ymin >= b[1] && sc.xmax <= b[2] && sc.ymax <= b[3]) return
    const mx = (sc.xmax - sc.xmin) * MARGE_VUS + 60 / sc.k, my = (sc.ymax - sc.ymin) * MARGE_VUS + 60 / sc.k
    const boite = [sc.xmin - mx, sc.ymin - my, sc.xmax + mx, sc.ymax + my]
    this.vus = { boite, listes: this.calques.map((K) => this.segmentsVus(K, boite)) }
  }

  // ─── La pose : les mobiles d'un segment, énumérés par leur rang dans la file (temps) ──────────────────────
  //  Mobile k de l'itinéraire : temps de parcours τ_k(t) = (phase + k·Δ + gigue_k + t) mod T_total, Δ = T_total / n.
  poserCalque(K, vus, sc, t, liste) {
    const pie = K.nom === "pietons", E = this.rep.metre_est_px, N = this.rep.metre_nord_px, marge = 40
    for (let q = 0; q < vus.length; q += 2) {
      const ii = vus[q], j = vus[q + 1], it = K.its[ii], Tt = it.T[it.segs.length]
      if (!(Tt > 0)) continue
      const n = Math.floor(it.flux * Tt + graineDe(ii, 3, 1))
      if (n < 1) continue
      const dl = Tt / n, ta = it.T[j], tb = it.T[j + 1], base = it.phase * Tt + t
      // k tels que (base + k·dl + gigue) mod Tt ∈ [ta, tb[ ; gigue ∈ [−0,3 ; 0,3]·dl, d'où un rang de marge de chaque côté
      const m0 = replier(ta - base, Tt)
      let k0 = Math.floor(m0 / dl) - 1, k1 = Math.ceil((m0 + tb - ta) / dl) + 1
      if (k1 - k0 + 1 >= n) { k0 = 0; k1 = n - 1 }
      for (let kk = k0; kk <= k1; kk++) {
        const k = replier(kk, n), gig = 0.6 * (graineDe(ii, 17, k) - 0.5) * dl * (pie ? 1 : 0.5)
        const tau = replier(base + k * dl + gig, Tt)
        if (tau < ta || tau >= tb) continue
        const sg = it.segs[j], u = it.C[j] + (tau - ta) * it.vit[j], sens = sg[2] >= sg[1] ? 1 : -1
        const p = this.situer(K, sg[0], sg[1] + sens * (u - it.C[j]))
        if (!p) continue
        const gE = p[2] * sens, gN = p[3] * sens, dE = gN, dN = -gE
        const dec = this.decalage(K, it, j, k, u) // à droite du sens de marche, fondu sur 3 m d'un segment au suivant
        const X = sc.ox + (p[0] + (E[0] * dE + N[0] * dN) * dec) * sc.k, Y = sc.oy + (p[1] + (E[1] * dE + N[1] * dN) * dec) * sc.k
        if (X < -marge || X > sc.largeur + marge || Y < -marge || Y > sc.hauteur + marge) continue
        const alpha = it.boucle ? 1 : Math.max(0, Math.min(1, u / FONDU_M, (it.L - u) / FONDU_M))
        if (alpha <= 0) continue
        liste.push({ X, Y, gE, gN, M: this.choisirModele(K, ii, k), pie, u, k, ii, alpha })
      }
    }
  }

  decalageSeg(K, it, j, k) {
    const v = K.voies[it.segs[j][0]]
    if (K.nom === "pietons") {
      const cote = graineDe(it.id, 23, k) < 0.5 ? -1 : 1
      return v[0] === 4 ? cote * (v[2] + 0.9) : cote * 0.35 * graineDe(k, 29, it.id)
    }
    if (v[6]) { const d = v[6][it.segs[j][2] >= it.segs[j][1] ? 0 : 1]; return d === null ? 0 : d } // vélos, bus : la file écrite par le calque
    return v[1] === 0 ? Math.max(0, Math.min(v[2] / 2, v[2] - 1.2)) : 0 // double sens : file de droite
  }

  decalage(K, it, j, k, u) {
    const R = 3, n = it.segs.length, dDeb = u - it.C[j], dFin = it.C[j + 1] - u
    let o = this.decalageSeg(K, it, j, k)
    if (dDeb < R && (j > 0 || it.boucle)) { const op = this.decalageSeg(K, it, (j - 1 + n) % n, k); o = op + (o - op) * (0.5 + 0.5 * dDeb / R) }
    else if (dFin < R && (j < n - 1 || it.boucle)) { const os = this.decalageSeg(K, it, (j + 1) % n, k); o = os + (o - os) * (0.5 + 0.5 * dFin / R) }
    return o
  }

  // Le tirage des modèles est COMMUN à toutes les voies (leçon des bateaux) : la graine est celle du mobile.
  choisirModele(K, ii, k) {
    const L = this.parType[K.type]
    return L[Math.floor(graineDe(ii, 41, k) * L.length) % L.length]
  }

  // ─── Le plancher et les sprites ──────────────────────────────────────────────────────────────────────────
  gainDe(M, k) {
    const P = PLANCHER[typeDe(M)]
    const kf = P.tailleFigee ? Math.max(k, 2 ** (P.tailleFigee - NIVEAU_REPERE)) : k // sous ce zoom : la taille qu'on y a
    const naturel = P.mesure === "H" ? M.H * Math.abs(this.rep.metre_hauteur_px[1]) * kf : M.L * this.rep.echelle_px_par_m * kf
    return Math.max(P.echelle ?? ECHELLE_VIVANTS, Math.max(1, Math.min(P.gain, P.px / naturel))) * kf / k
  }

  capIndex(gE, gN) {
    const n = this.sprites.caps, a = Math.atan2(gE, gN) * 180 / Math.PI // relèvement de grille de l'avant
    return ((Math.round(a / (360 / n)) % n) + n) % n
  }

  cleSprite(o) {
    if (!o.pie) return o.M.cle
    const pas = Math.floor(o.u / 0.7 + graineDe(o.ii, 5, o.k) * 2) // une foulée tous les 0,7 m
    return pas & 1 ? o.M.cle.replace(/-g$/, "-d") : o.M.cle
  }

  // Le sprite à dessiner : dans la pyramide pré-réduite, le plus grand niveau dont l'échelle ne dépasse pas
  // 2 × k × gain × dpr (le navigateur ne réduit plus que d'un facteur entre 0,5 et 0,71) ; sinon l'atlas principal.
  spriteDe(o, k, gain) {
    const cle = this.cleSprite(o), c = this.capIndex(o.gE, o.gN), n = this.reduits.S.niveaux[cle]
    const cible = 2 * k * gain * (window.devicePixelRatio || 1)
    if (n && this.sprites.echelles[cle] > cible) {
      let i = 0
      while (i < n.length - 1 && n[i][0] > cible) i++ // niveaux rangés par échelle décroissante
      return { im: this.reduits.atlas, s: this.reduits.S.index[n[i][1]][c], f: k / n[i][0] * gain }
    }
    return { im: this.atlas, s: this.sprites.index[cle][c], f: k / this.sprites.echelles[cle] * gain }
  }

  // ─── La carte des codes (propriété, niveau 8) ───────────────────────────────────────────────────────────────
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
      ent.a = a; ent.w = im.width
    }, () => { ent.a = false })
  }

  // -1 : pas encore lue (tenue pour du sol : on montre plutôt qu'on cache) ; 0 : dehors.
  codeEn(nx, ny) {
    nx = Math.floor(nx); ny = Math.floor(ny)
    if (nx < 0 || ny < 0) return 0
    const tx = nx >> 8, ty = ny >> 8, d = this.codes.get(tx * 4096 + ty)
    if (!d) { this.chargerCode(tx, ty); return -1 }
    if (d.a === null) return -1
    if (d.a === false) return 0
    return d.a[(ny - (ty << 8)) * d.w + (nx - (tx << 8))]
  }

  // ─── L'occlusion : la règle des colonnes des bateaux, en DÉCOUPE sur la toile (méthode « clip » de la démo) ──
  colonnesMasquees(sc, o, gain) {
    const M = o.M, gE = o.gE, gN = o.gN, dE = gN, dN = -gE, E = this.rep.metre_est_px, N = this.rep.metre_nord_px, k = sc.k * gain
    const ax = (E[0] * gE + N[0] * gN) * k, ay = (E[1] * gE + N[1] * gN) * k, bx = (E[0] * dE + N[0] * dN) * k, by = (E[1] * dE + N[1] * dN) * k
    const A = M.L / 2, B = M.W / 2
    const coins = [[A, B], [A, -B], [-A, -B], [-A, B]].map((q) => [o.X + ax * q[0] + bx * q[1], o.Y + ay * q[0] + by * q[1]])
    const xs = coins.map((p) => p[0]), x0 = Math.floor(Math.min(...xs)) - 1, x1 = Math.ceil(Math.max(...xs)) + 1
    const r = []
    for (let x = x0; x < x1; x++) {
      const xc = x + 0.5, nx = (xc - sc.ox) / sc.k
      let bas = -Infinity
      for (let e = 0; e < 4; e++) {
        const p = coins[e], q = coins[(e + 1) & 3]
        if ((p[0] - xc) * (q[0] - xc) > 0 || p[0] === q[0]) continue
        const yy = p[1] + (q[1] - p[1]) * (xc - p[0]) / (q[0] - p[0])
        if (yy > bas) bas = yy
      }
      if (bas === -Infinity) { if (Math.abs(xc - o.X) < 1) bas = o.Y; else continue }
      const y = Math.floor(bas - 0.5)
      if (estVolume(this.codeEn(nx, (y + 0.5 - sc.oy) / sc.k))) {
        let haut = y
        const borne = y - 200
        while (haut - 1 > borne && estVolume(this.codeEn(nx, (haut - 0.5 - sc.oy) / sc.k))) haut--
        r.push(x, haut)
      }
    }
    return r
  }

  peindre(ctx, sc, o) {
    const gain = this.gainDe(o.M, sc.k), p = this.spriteDe(o, sc.k, gain), s = p.s, f = p.f
    const col = this.colonnesMasquees(sc, o, gain)
    ctx.globalAlpha = o.alpha
    if (col.length) {
      // la partie permise de chaque colonne est au-dessus de `haut` dans une colonne masquée, entière ailleurs ;
      // les colonnes voisines de même hauteur sont fusionnées en un rectangle
      const x0 = Math.floor(o.X - s[4] * f) - 1, y0 = Math.floor(o.Y - s[5] * f) - 1, w = Math.ceil(s[2] * f) + 3, h = Math.ceil(s[3] * f) + 3
      const hautDe = {}
      for (let q = 0; q < col.length; q += 2) hautDe[col[q]] = col[q + 1]
      ctx.save(); ctx.beginPath()
      let debut = x0, hc = hautDe[x0] ?? y0 + h
      for (let x = x0 + 1; x <= x0 + w; x++) {
        const hx = x === x0 + w ? NaN : hautDe[x] ?? y0 + h
        if (hx !== hc) { if (hc > y0) ctx.rect(debut, y0, x - debut, hc - y0); debut = x; hc = hx }
      }
      ctx.clip()
    }
    ctx.drawImage(p.im, s[0], s[1], s[2], s[3], o.X - s[4] * f, o.Y - s[5] * f, s[2] * f, s[3] * f)
    if (col.length) ctx.restore()
    ctx.globalAlpha = 1
  }

  // ─── L'animation ──────────────────────────────────────────────────────────────────────────────────────────
  demarrer() {
    if (this.actif) return
    this.actif = true
    if (!this.toile) {
      this.toile = document.createElement("canvas")
      this.toile.className = "vivants"
      Object.assign(this.toile.style, { position: "fixed", left: "0", top: "0", pointerEvents: "none" })
      this.ctx = this.toile.getContext("2d")
    }
    this.ancre.after(this.toile)
    this.derniere = 0
    this.cleVue = null
    const boucle = (tms) => {
      if (!this.actif) return
      this.raf = requestAnimationFrame(boucle)
      const v = this.vue(), cle = `${v.cx},${v.cy},${v.s},${v.W},${v.H}`
      if (document.hidden || (cle === this.cleVue && tms - this.derniere < INTERVALLE_MS)) return
      this.cleVue = cle; this.derniere = tms
      this.image(v)
    }
    this.raf = requestAnimationFrame(boucle)
  }

  arreter() {
    this.actif = false
    cancelAnimationFrame(this.raf)
    this.toile?.remove()
  }

  image(v) {
    const j0 = performance.now(), dpr = window.devicePixelRatio || 1, toile = this.toile, ctx = this.ctx
    const sc = { k: v.s, niveau: NIVEAU_REPERE + Math.log2(v.s), ox: v.W / 2 - v.cx * v.s, oy: v.H / 2 - v.cy * v.s, largeur: v.W, hauteur: v.H,
                 xmin: v.cx - v.W / 2 / v.s, xmax: v.cx + v.W / 2 / v.s, ymin: v.cy - v.H / 2 / v.s, ymax: v.cy + v.H / 2 / v.s }
    // la toile s'affiche sur W × H px d'appareil EXACTEMENT (taille CSS = support / dpr) : à dpr 0,8, Firefox
    // rééchantillonnait sinon la toile entière (démo nancy-3d, 20/10, § 14)
    const W = Math.round(v.W * dpr), H = Math.round(v.H * dpr)
    if (toile.width !== W || toile.height !== H || toile.dprPose !== dpr) {
      toile.width = W; toile.height = H; toile.dprPose = dpr
      toile.style.width = `${W / dpr}px`; toile.style.height = `${H / dpr}px`
    }
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H)
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    const liste = []
    // un niveau se montre à partir de son zoom entier (la démo n'a que des zooms entiers) : jamais plus petit
    // qu'aux niveaux où les planchers ont été jugés
    const niveaux = this.calques.map((K) => PLANCHER[K.type].niveauMin)
    if (sc.niveau >= Math.min(...niveaux) - 1e-9) {
      this.majVus(sc)
      const t = this.horloge()
      this.calques.forEach((K, i) => { if (sc.niveau >= niveaux[i] - 1e-9) this.poserCalque(K, this.vus.listes[i], sc, t, liste) })
    }
    liste.sort((a, b) => a.Y - b.Y)
    const n = { pieton: 0, voiture: 0, velo: 0, bus: 0, trolleybus: 0 }
    for (const o of liste) { this.peindre(ctx, sc, o); n[typeDe(o.M)]++ }
    this.stats = { pietons: n.pieton, voitures: n.voiture, velos: n.velo, bus: n.bus, trolleybus: n.trolleybus,
                   js: performance.now() - j0, niveau: sc.niveau }
  }

  // Rien si l'appareil demande moins d'animations.
  static permis() { return !window.matchMedia(MOINS_DE_MOUVEMENT).matches }
}
