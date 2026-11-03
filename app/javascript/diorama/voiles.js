// Les voiles du ciel : ombres de nuages (météo « nuageux », de jour) et brouillard (météo « brouillard »). 03/11/2026,
// d'après l'audit du diorama (rapports/audit-diorama-2026-11-03.md, pistes 9 et suivantes).
//
// Même patron que les précipitations (diorama/precipitations) — un canevas dans le volet `meteo` (z-index 450 : au-dessus
// des dalles, des bateaux et des vivants, sous les pins à 600) —, avec une différence de fond : pluie et neige tombent
// DEVANT la maquette et s'ancrent à l'écran ; une ombre de nuage et une nappe de brouillard sont POSÉES SUR la maquette.
// Elles se dimensionnent donc en MÈTRES et s'ancrent au SOL : quand on fait glisser la carte, elles glissent avec elle (la
// toile vit dans un volet de la carte, et on ne la recale qu'en la repeignant). Un mètre du sol se porte sur la mosaïque
// par les deux vecteurs de la projection (`repereSol`) : une tache ronde au sol se tasse de cos 50° le long de la visée.
//
// Sobriété : la toile est peinte à une FRACTION de la taille de l'écran (`resolution`) puis étirée — tout y est flou, rien ne
// se perd, et le remplissage coûte 9 à 16 fois moins ; 15 images par seconde au plus (une ombre à 8 m/s avance d'un
// pixel et quart par image au niveau 8) ; suspendue onglet caché ou carte hors de l'écran ; masquée pendant un zoom ;
// AUCUNE toile si l'appareil demande moins d'animations (prefers-reduced-motion) ou économise ses données (saveData).
// Apparition et retrait en fondu d'opacité (CSS) : la météo ou le moment qui change ne fait pas claquer un interrupteur.
//
// Les motifs sont tirés à la GRAINE, pas au hasard, et la dérive suit l'heure absolue : deux visiteurs au même instant
// voient les mêmes nuages au même endroit.
//
// Crochet d'instrument, déclaré (il ne change rien quand on ne le demande pas) :
//   ?voiles-t=S   fige l'horloge des deux voiles à S secondes (captures comparables)
import { NUAGES, BROUILLARD } from "diorama/reglages"
import { soleil } from "diorama/soleil"

const NIVEAU_REPERE = 8
const MOINS_DE_MOUVEMENT = "(prefers-reduced-motion: reduce)"

function graineDe(i, j, k) {
  let h = (i * 374761393 + j * 668265263 + k * 2246822519) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}
const replier = (a, b) => ((a % b) + b) % b
const entre = ([a, b], g) => a + (b - a) * g
const lisse = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t) }

// Le repère du sol sur la mosaïque (niveau 8) : un point origine et les vecteurs d'un mètre vers l'est et vers le nord de
// la GRILLE Lambert-93 (la projection est affine en L93 : l'origine n'importe pas). `projection` : diorama_projection.
export function repereSol(projection) {
  const x = 933000, y = 6848000, o = projection.pixelL93(x, y)
  const e = projection.pixelL93(x + 1, y), n = projection.pixelL93(x, y + 1)
  const E = [e[0] - o[0], e[1] - o[1]], N = [n[0] - o[0], n[1] - o[1]], det = E[0] * N[1] - N[0] * E[1]
  return { o, E, N, inv: [N[1] / det, -N[0] / det, -E[1] / det, E[0] / det], pxParM: Math.hypot(E[0], E[1]) }
}

// Une tache douce (profil en cloche, transparente au bord) d'une couleur, sur un petit canevas recopié ensuite à
// l'échelle de chaque bulle : aucun flou calculé à l'image.
function tacheDouce(rgb, cote = 64) {
  const c = document.createElement("canvas")
  c.width = c.height = cote
  const cx = c.getContext("2d"), g = cx.createRadialGradient(cote / 2, cote / 2, 0, cote / 2, cote / 2, cote / 2)
  for (let i = 0; i <= 8; i++) {
    const r = i / 8
    g.addColorStop(r, `rgba(${rgb},${Math.exp(-4 * r * r) * (1 - r)})`)
  }
  cx.fillStyle = g
  cx.fillRect(0, 0, cote, cote)
  return c
}

// La base commune : une toile ancrée au sol, peinte en basse résolution, avec sa boucle et ses garde-fous.
class ToileAncree {
  constructor(L, carte, projection, reglages, classe) {
    this.L = L
    this.carte = carte
    this.reglages = reglages
    this.classe = classe
    this.repere = repereSol(projection)
    const params = new URLSearchParams(location.search)
    this.horlogeFigee = params.has("voiles-t") ? parseFloat(params.get("voiles-t")) : null
    this.horsVue = false
    this.opacite = 0
    this.stats = { images: 0, bulles: 0 }
    this.reduit = window.matchMedia(MOINS_DE_MOUVEMENT)
    this.surReduit = () => this.majActivite()
    this.surVisibilite = () => this.majActivite()
    this.surZoomDebut = () => { if (this.toile) this.toile.style.visibility = "hidden" }
    this.surFin = () => { if (this.toile) { this.toile.style.visibility = ""; this.vueChangee(); this.dessiner() } }
    this.surTaille = () => { if (this.toile) { this.dimensionner(); this.vueChangee(); this.dessiner() } }
    this.reduit.addEventListener("change", this.surReduit)
    document.addEventListener("visibilitychange", this.surVisibilite)
  }

  static permis() {
    return !window.matchMedia(MOINS_DE_MOUVEMENT).matches && !navigator.connection?.saveData
  }

  // Secondes de l'horloge des voiles : l'heure absolue (mêmes nuages pour tous), ou l'horloge figée du crochet.
  horloge() { return this.horlogeFigee ?? Date.now() / 1000 }

  majActivite() {
    if (this.detruit) return
    if (!ToileAncree.permis()) { this.retirer(); return }
    if (!this.toile) this.poser()
    if (document.hidden || this.horsVue) this.suspendre()
    else this.reprendre()
  }

  pauseHorsVue(hors) {
    this.horsVue = hors
    this.majActivite()
  }

  poser() {
    const volet = this.carte.getPane("meteo") || this.carte.createPane("meteo")
    volet.style.zIndex = 450
    volet.style.pointerEvents = "none"
    this.toile = this.L.DomUtil.create("canvas", `acc-voile ${this.classe}`, volet)
    this.toile.setAttribute("aria-hidden", "true")
    Object.assign(this.toile.style, { position: "absolute", left: "0", top: "0", opacity: "0",
                                      transition: `opacity ${BROUILLARD.fondu_ms}ms ease-in-out`, pointerEvents: "none" })
    this.ctx = this.toile.getContext("2d")
    this.carte.on("zoomstart", this.surZoomDebut)
    this.carte.on("zoomend moveend viewreset", this.surFin)
    this.carte.on("resize", this.surTaille)
    this.dimensionner()
    this.vueChangee()
    this.dessiner()
    // l'opacité visée est posée APRÈS une image : la transition CSS joue alors le fondu d'apparition
    requestAnimationFrame(() => requestAnimationFrame(() => this.appliquerOpacite()))
  }

  // L'opacité CSS de la toile : la force du voile (fondu CSS entre deux valeurs).
  majOpacite(o) {
    this.opacite = o
    this.appliquerOpacite()
  }

  appliquerOpacite() { if (this.toile && !this.sortie) this.toile.style.opacity = String(this.opacite) }

  dimensionner() {
    const { x, y } = this.carte.getSize(), r = this.reglages.resolution
    this.largeur = x; this.hauteur = y
    this.toile.width = Math.max(1, Math.ceil(x * r)); this.toile.height = Math.max(1, Math.ceil(y * r))
    this.toile.style.width = `${x}px`; this.toile.style.height = `${y}px`
  }

  vueChangee() {}

  // Le passage niveau 8 → écran : X = px × k + ox (px CSS), comme les bateaux (mobiles.js#cadre).
  cadre() {
    const z = this.carte.getZoom(), k = 2 ** (z - NIVEAU_REPERE), b = this.carte.getPixelBounds()
    return { k, ox: -b.min.x, oy: -b.min.y, r: this.reglages.resolution }
  }

  reprendre() {
    if (this.image || !this.toile) return
    this.avant = -Infinity
    const intervalle = 1000 / this.reglages.images_s - 2
    const pas = (t) => {
      this.image = requestAnimationFrame(pas)
      if (t - this.avant < intervalle) return
      this.avant = t
      this.dessiner()
    }
    this.image = requestAnimationFrame(pas)
  }

  suspendre() {
    if (this.image) cancelAnimationFrame(this.image)
    this.image = null
  }

  dessiner() {
    if (!this.toile || this.toile.style.visibility === "hidden") return
    // la toile est ramenée au coin haut-gauche de l'écran À CHAQUE peinture, jamais entre deux : pendant un glissé, elle
    // suit donc la carte (son volet est dans celui de la carte), comme le sol qu'elle couvre
    this.L.DomUtil.setPosition(this.toile, this.carte.containerPointToLayerPoint([0, 0]))
    const sc = this.cadre(), ctx = this.ctx
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.globalAlpha = 1
    ctx.globalCompositeOperation = "source-over"
    ctx.clearRect(0, 0, this.toile.width, this.toile.height)
    this.stats.bulles = 0
    this.peindre(ctx, sc, this.horloge())
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.globalAlpha = 1
    ctx.globalCompositeOperation = "source-over"
    this.stats.images++
  }

  // Le rectangle de la vue en mètres de grille (relatifs à l'origine du repère), élargi de `marge` m.
  boiteMetres(sc, marge) {
    const R = this.repere, coins = [[0, 0], [this.largeur, 0], [0, this.hauteur], [this.largeur, this.hauteur]]
    let e0 = Infinity, e1 = -Infinity, n0 = Infinity, n1 = -Infinity
    for (const [x, y] of coins) {
      const px = (x - sc.ox) / sc.k - R.o[0], py = (y - sc.oy) / sc.k - R.o[1]
      const e = R.inv[0] * px + R.inv[1] * py, n = R.inv[2] * px + R.inv[3] * py
      e0 = Math.min(e0, e); e1 = Math.max(e1, e); n0 = Math.min(n0, n); n1 = Math.max(n1, n)
    }
    return [e0 - marge, n0 - marge, e1 + marge, n1 + marge]
  }

  // Des bulles d'un motif PÉRIODIQUE (période P m sur les deux axes de la grille), poussées de (dE, dN) m, peintes avec
  // la tache `motif` : chaque bulle { e, n, r } est une ellipse au sol (un cercle de rayon r m, tassé par la projection).
  poserBulles(ctx, sc, bulles, P, dE, dN, motif, rmax) {
    const [e0, n0, e1, n1] = this.boiteMetres(sc, rmax), R = this.repere, s = sc.k * sc.r
    for (const b of bulles) {
      const be = replier(b.e + dE, P), bn = replier(b.n + dN, P)
      for (let ie = Math.floor((e0 - be) / P) + 1; be + ie * P <= e1; ie++) {
        for (let jn = Math.floor((n0 - bn) / P) + 1; bn + jn * P <= n1; jn++) {
          const e = be + ie * P, n = bn + jn * P
          const X = (R.o[0] + R.E[0] * e + R.N[0] * n) * sc.k + sc.ox, Y = (R.o[1] + R.E[1] * e + R.N[1] * n) * sc.k + sc.oy
          ctx.setTransform(R.E[0] * b.r * s, R.E[1] * b.r * s, R.N[0] * b.r * s, R.N[1] * b.r * s, X * sc.r, Y * sc.r)
          ctx.drawImage(motif, -1, -1, 2, 2)
          this.stats.bulles++
        }
      }
    }
  }

  retirer() {
    this.suspendre()
    if (!this.toile) return
    this.carte.off("zoomstart", this.surZoomDebut)
    this.carte.off("zoomend moveend viewreset", this.surFin)
    this.carte.off("resize", this.surTaille)
    this.toile.remove()
    this.toile = null
  }

  // Retrait en fondu (la toile s'efface puis part) ; `net` : tout de suite (la carte s'en va).
  detruire(net = false) {
    if (this.detruit) return
    this.detruit = true
    this.reduit.removeEventListener("change", this.surReduit)
    document.removeEventListener("visibilitychange", this.surVisibilite)
    if (net || !this.toile) { this.retirer(); return }
    this.sortie = true
    this.toile.style.opacity = "0"
    setTimeout(() => this.retirer(), BROUILLARD.fondu_ms)
  }
}

// ─── Ombres de nuages ─────────────────────────────────────────────────────────────────────────────────────────
// La toile peint la COUVERTURE (bulles opaques au cœur, qui se fondent entre elles) ; sa force est l'opacité CSS de la
// toile, NUAGES.opacite × l'intensité du moment : deux bulles qui se recouvrent ne font donc pas une ombre plus noire.
export class OmbresNuages extends ToileAncree {
  constructor(L, carte, { projection, moment }) {
    super(L, carte, projection, NUAGES, "acc-nuages")
    const N = NUAGES, bulles = []
    for (let c = 0; c < N.nuages; c++) {
      const e = graineDe(c, 1, 7) * N.periode_m, n = graineDe(c, 2, 7) * N.periode_m, R = entre(N.rayon_m, graineDe(c, 3, 7))
      const nb = Math.round(entre(N.bulles, graineDe(c, 4, 7)))
      for (let q = 0; q < nb; q++) {
        // les bulles d'un nuage : autour de son centre, plus petites au bord ; le nuage s'étire dans le sens du vent
        const a = graineDe(c, q, 11) * 2 * Math.PI, d = (q === 0 ? 0 : 0.35 + 0.45 * graineDe(c, q, 12)) * R
        const v = N.vent_vers_deg * Math.PI / 180, ux = Math.sin(v), uy = Math.cos(v)
        const along = Math.cos(a) * d * 1.5, across = Math.sin(a) * d * 0.8
        bulles.push({ e: e + along * ux - across * uy, n: n + along * uy + across * ux, r: R * (q === 0 ? 0.8 : 0.45 + 0.3 * graineDe(c, q, 13)) })
      }
    }
    this.bulles = bulles
    this.rmax = Math.max(...bulles.map((b) => b.r))
    this.motif = tacheDouce(N.couleur)
    this.moment = moment
    this.majActivite()
    this.majMoment(moment)
  }

  majMoment(moment) {
    this.moment = moment
    this.majOpacite(NUAGES.opacite * (NUAGES.intensite[moment] ?? 0))
  }

  peindre(ctx, sc, t) {
    const N = NUAGES, v = N.vent_vers_deg * Math.PI / 180, d = N.vent_m_s * t
    this.poserBulles(ctx, sc, this.bulles, N.periode_m, d * Math.sin(v), d * Math.cos(v), this.motif, this.rmax)
  }
}

// L'épaisseur du brouillard selon la hauteur du soleil (degrés) : 1 sous l'horizon, `plancher` au-dessus de `dissipe_deg`,
// une interpolation douce entre les deux (l'aube qui passe au jour l'éclaircit peu à peu) ; la nuit, ×`nuit`.
export function densiteBrouillard(hauteur, moment) {
  const B = BROUILLARD
  const f = 1 - (1 - B.plancher) * lisse(0, B.dissipe_deg, hauteur)
  return moment === "nuit" ? f * B.nuit : f
}

// ─── Brouillard ───────────────────────────────────────────────────────────────────────────────────────────────
// Peint avec ses vraies opacités : le voile, l'eau plus épaisse, les nappes plus claires qui dérivent, puis les volumes
// (bâti, houppiers) qui percent le voile. La force d'ensemble — la dissipation avec le soleil — est l'opacité CSS.
//   eau : () → { routes: [{ trace (px L8, x, y, …), largeur (m) }] } | null — les itinéraires des bateaux (mobiles.js#eauVue)
//   masque : () → { image, ox, oy, k, marge } | null — les volumes de la vue (mobiles.js#masqueVu), dès le niveau 7
export class Brouillard extends ToileAncree {
  constructor(L, carte, { projection, moment, auto, eau = null, masque = null }) {
    super(L, carte, projection, BROUILLARD, "acc-brouillard")
    const B = BROUILLARD.nappes, bulles = []
    for (let q = 0; q < B.nombre; q++) {
      bulles.push({ e: graineDe(q, 1, 31) * B.periode_m, n: graineDe(q, 2, 31) * B.periode_m, r: entre(B.rayon_m, graineDe(q, 3, 31)) })
    }
    this.nappes = bulles
    this.rmax = Math.max(...bulles.map((b) => b.r))
    this.eau = eau
    this.masque = masque
    this.eauToile = document.createElement("canvas")
    this.eauCadre = null
    this.stats.eau = 0
    this.moment = moment
    this.auto = auto
    this.majMoment(moment, auto)
    this.majActivite()
  }

  // Le moment (pour la couleur) et l'automatique (vraie hauteur du soleil, ou celle prêtée au moment choisi).
  majMoment(moment, auto) {
    this.moment = moment
    this.auto = auto
    this.couleur = BROUILLARD.couleurs[moment] || BROUILLARD.couleurs.jour
    this.motifNappe = tacheDouce(moment === "nuit" ? "150,158,180" : "255,255,255")
    this.majDensite()
  }


  hauteurSoleil() {
    return this.auto ? soleil(new Date()).hauteur : BROUILLARD.hauteur_du_moment[this.moment] ?? 25
  }

  majDensite() {
    this.hauteur = this.hauteurSoleil()
    this.densiteLe = performance.now()
    this.majOpacite(densiteBrouillard(this.hauteur, this.moment))
  }

  vueChangee() { this.eauCadre = null }

  // L'eau de la vue (élargie d'un quart de chaque côté), tracée et floutée UNE fois par vue : à l'image, une recopie.
  construireEau(sc) {
    const donnees = this.eau?.()
    if (!donnees?.routes?.length) return false
    const B = BROUILLARD, W = this.toile.width, H = this.toile.height, mx = Math.ceil(W / 4), my = Math.ceil(H / 4)
    const c = this.eauToile
    c.width = W + 2 * mx; c.height = H + 2 * my
    const cx = c.getContext("2d"), s = sc.k * sc.r, pxParM = this.repere.pxParM
    cx.clearRect(0, 0, c.width, c.height)
    cx.filter = `blur(${Math.max(1, B.flou_eau_m * pxParM * s).toFixed(2)}px)`
    cx.strokeStyle = `rgb(${this.couleur})`
    cx.lineCap = cx.lineJoin = "round"
    let traces = 0
    for (const r of donnees.routes) {
      const t = r.trace
      if (t.length < 4) continue
      cx.lineWidth = Math.max(2, (r.largeur + 2 * B.berge_m) * pxParM * s)
      cx.beginPath()
      for (let j = 0; j < t.length; j += 2) {
        const x = (t[j] * sc.k + sc.ox) * sc.r + mx, y = (t[j + 1] * sc.k + sc.oy) * sc.r + my
        if (j === 0) cx.moveTo(x, y); else cx.lineTo(x, y)
      }
      cx.stroke()
      traces++
    }
    cx.filter = "none"
    this.eauCadre = { ox: sc.ox, oy: sc.oy, k: sc.k, mx, my, couleur: this.couleur }
    this.stats.eau = traces
    return true
  }

  peindre(ctx, sc, t) {
    const B = BROUILLARD
    if (performance.now() - this.densiteLe > 30000) this.majDensite() // le soleil monte : relu toutes les 30 s
    const W = this.toile.width, H = this.toile.height
    // 1. le voile
    ctx.fillStyle = `rgba(${this.couleur},${B.voile})`
    ctx.fillRect(0, 0, W, H)
    // 2. l'eau, qui respire lentement (période de 40 s)
    const ec = this.eauCadre
    if (!ec || ec.k !== sc.k || ec.couleur !== this.couleur) this.construireEau(sc)
    if (this.eauCadre) {
      const e = this.eauCadre
      ctx.globalAlpha = B.eau * (0.85 + 0.15 * Math.sin(t * 2 * Math.PI / 40))
      ctx.drawImage(this.eauToile, (sc.ox - e.ox) * sc.r - e.mx, (sc.oy - e.oy) * sc.r - e.my)
    }
    // 3. les nappes, qui dérivent
    const n = B.nappes, v = n.vent_vers_deg * Math.PI / 180, d = n.vent_m_s * t
    ctx.globalAlpha = n.opacite
    this.poserBulles(ctx, sc, this.nappes, n.periode_m, d * Math.sin(v), d * Math.cos(v), this.motifNappe, this.rmax)
    // 4. les volumes percent le voile : le brouillard reste au sol, les toits et les houppiers en sortent
    const m = this.masque?.()
    if (m && m.k === sc.k) {
      ctx.setTransform(sc.r, 0, 0, sc.r, 0, 0)
      ctx.globalCompositeOperation = "destination-out"
      ctx.globalAlpha = B.volumes
      ctx.drawImage(m.image, sc.ox - m.ox - m.marge, sc.oy - m.oy - m.marge)
      this.stats.volumes = true
    } else this.stats.volumes = false
  }
}
