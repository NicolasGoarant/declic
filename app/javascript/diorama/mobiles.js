// Les bateaux : péniches sur le canal, petits bateaux sur la Meurthe, posés SUR la maquette.
// Données de nancy-3d (rapports/animations-v1, jeu R2 « mobiles-v1 ») : le calque des itinéraires sur l'eau
// (bateaux.json, format nancy-3d/calque-vivant v2, en pixels de mosaïque au niveau 8) et l'atlas des sprites
// cuits pour la caméra du diorama (50°, azimut 200° en relèvement de grille Lambert-93 de l'œil vu du centre).
//
// Un canevas dans un volet Leaflet entre les dalles et les marqueurs (z-index 500 : au-dessus de la météo à
// 450, sous les pins à 600), recalé à chaque déplacement comme celui des précipitations.
//
// Ce que fait chaque image (rien n'est gardé d'une image à l'autre : la position est une fonction de l'heure) :
//   1. la POSE : sur chaque intervalle de circulation, des bateaux régulièrement espacés, tirés à la graine,
//      une file par sens (chacun à tribord) — une seule, vers l'aval, là où l'eau a moins de 12 m de large ;
//      même vitesse pour toute une file, donc pas de dépassement ; FONDU d'opacité aux deux bouts ;
//   2. le SILLAGE : des traits fins groupés par opacité, un seul stroke() par cran ;
//   3. le MASQUE AU SOL : la carte de propriété (dalles de codes) retire le sillage sous les ponts et les arbres ;
//   4. les BATEAUX, du plus loin au plus près, chacun masqué colonne par colonne par les volumes qui le couvrent.
// Un bateau qui passe sous un pont-volume est donc caché par le pont, progressivement, et non retiré d'un coup.
// Les tabliers posés À PLAT, les houppiers des arbres du style et les bouts de canal que la dalle ne dessine pas
// sont du « sol » pour la propriété : le calque les déclare (`couverts`), et le bateau s'y efface en fondu.
//
// Sobriété : 30 images par seconde au plus, rien sous le niveau NIVEAU_MIN, animation suspendue quand l'onglet
// est caché, et AUCUN bateau si l'appareil demande moins d'animations (prefers-reduced-motion).
//
// Crochets d'instrument, déclarés (ils ne changent rien quand on ne les demande pas) :
//   ?mobiles-t=S     fige l'horloge à S secondes (captures comparables)
//   ?mobiles-banc=1  relève les instants d'image et le coût JS dans `banc`

const NIVEAU_REPERE = 8
const NIVEAU_MIN = 7                // en dessous, une péniche fait moins de 20 px : on ne pose rien
const MOINS_DE_MOUVEMENT = "(prefers-reduced-motion: reduce)"
const INTERVALLE_MS = 1000 / 30 - 2
const Z_VOLET = 500
const DENSITE = [3.0, 4.0]          // CHOISI : bateaux par km et par file — péniches (canal), petits bateaux (rivière)
const VITESSE = [1.0, 1.6]          // CHOISI : m/s d'une file, ± 10 % tirés par file
const FONDU_M = 15                  // CHOISI : longueur du fondu aux bouts d'un intervalle
const RECUL_CONTOUR_M = 12          // CHOISI : retrait, en m, d'un bout d'intervalle coupé par le contour de la Métropole
const LARGEUR_DEUX_FILES_M = 12     // sous cette largeur (borne basse), deux bateaux ne se croisent pas
const CRANS = 5, SILLAGE_RGB = "236,244,246", PAS_M = 1.5, OUVERTURE = 0.25 // CHOISIS ; 0,25 = tan 14°
const MARGE_MASQUE = 384            // px : le masque au sol tient pendant un glissé de cette ampleur

function graineDe(i, j, k) {
  let h = (i * 374761393 + j * 668265263 + k * 2246822519) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}
const replier = (a, b) => ((a % b) + b) % b
const estVolume = (c) => c === 2 || c === 4 // propriété : 1 sol posé, 2 volume posé, 3 sol repris, 4 volume repris

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

export class Mobiles {
  // options : dossier (URL du jeu mobiles), propriete (chemin "8/x/y" → URL de la dalle de codes),
  //           dallesPropriete ({ 8: Set("x/y") } : les dalles publiées ; une absente vaut « dehors », code 0),
  //           contient (px L8 → booléen : dans le contour de la Métropole, hors duquel les dalles sont découpées)
  constructor(L, carte, { dossier, propriete, dallesPropriete, contient = null }) {
    this.contient = contient
    this.L = L
    this.carte = carte
    this.dossier = dossier
    this.urlCode = propriete
    this.dallesCodes = dallesPropriete?.[NIVEAU_REPERE] || null
    this.codes = new Map()
    const params = new URLSearchParams(location.search)
    this.horlogeFigee = params.has("mobiles-t") ? parseFloat(params.get("mobiles-t")) : null
    this.banc = params.get("mobiles-banc") === "1" ? { instants: [], js: [], peints: [], segments: [] } : null
    this.stats = { peints: 0, segments: 0, js: 0, niveau: null, masque: false }
    this.t0 = performance.now()
    this.reduit = window.matchMedia(MOINS_DE_MOUVEMENT)
    this.surReduit = () => this.majActivite()
    this.surVisibilite = () => this.majActivite()
    this.surDeplacement = () => this.recaler()
    this.surFin = () => { this.toileVisible(true); this.construireMasque(); this.majActivite() }
    this.surZoomDebut = () => this.toileVisible(false)
    this.surTaille = () => { this.dimensionner(); this.construireMasque() }
    this.reduit.addEventListener("change", this.surReduit)
    document.addEventListener("visibilitychange", this.surVisibilite)
    this.pret = this.charger().then(() => this.majActivite(), (e) => console.warn("mobiles : jeu illisible", e))
  }

  async charger() {
    const u = (n) => `${this.dossier}/${n}`
    const [eau, sprites, modeles, atlas] = await Promise.all([
      lireJSON(u("bateaux.json")), lireJSON(u("sprites-bateaux.json")), lireJSON(u("modeles-bateaux.json")),
      lireImage(u("sprites-bateaux.png"), false)
    ])
    if (this.detruit) return
    if (!eau.itineraires || !eau.camera) throw new Error("bateaux.json sans itinéraires ni caméra (format v2 attendu)")
    Object.assign(this, { eau, sprites, atlas, modeles: modeles.modeles })
    this.preparer()
  }

  // ─── Les itinéraires : abscisse au sol de chaque sommet, direction, emprise de chaque intervalle ─────────────
  preparer() {
    const cam = this.eau.camera, E = cam.metre_est_px, N = cam.metre_nord_px, det = E[0] * N[1] - N[0] * E[1]
    this.inv = [N[1] / det, -N[0] / det, -E[1] / det, E[0] / det] // px L8 → mètres (E, N) au sol
    this.cam = cam
    this.parType = [[], []]
    this.modeles.forEach((m, q) => this.parType[m.type === "peniche" ? 0 : 1].push(q))
    this.routes = this.eau.itineraires.map(([type, , , trace, largeurs, intervalles, couverts = [], couverts9 = null], i) => {
      const n = trace.length / 2, cum = new Float64Array(n), dirs = new Float64Array(2 * n)
      let s = 0
      for (let j = 1; j < n; j++) {
        const dx = trace[2 * j] - trace[2 * j - 2], dy = trace[2 * j + 1] - trace[2 * j - 1]
        const gE = this.inv[0] * dx + this.inv[1] * dy, gN = this.inv[2] * dx + this.inv[3] * dy, lm = Math.hypot(gE, gN)
        s += lm; cum[j] = s
        dirs[2 * (j - 1)] = lm > 0 ? gE / lm : 1; dirs[2 * (j - 1) + 1] = lm > 0 ? gN / lm : 0
      }
      if (n > 1) { dirs[2 * (n - 1)] = dirs[2 * (n - 2)]; dirs[2 * (n - 1) + 1] = dirs[2 * (n - 2) + 1] }
      // les niveaux 8 et 9 du style ne dessinent pas la même eau partout : chaque niveau a ses portions couvertes
      const route = { i, type, trace, cum, dirs, largeurs, couvertsParNiveau: { 8: couverts, 9: couverts9 || couverts }, couverts, Lm: s }
      route.intervalles = this.recouper(route, intervalles).map(([s0, s1], j) => {
        // les sommets de l'intervalle ET ses deux extrémités : un bout coupé au contour tombe souvent au milieu d'un segment
        const boite = [Infinity, Infinity, -Infinity, -Infinity], etendre = (x, y) => {
          boite[0] = Math.min(boite[0], x); boite[1] = Math.min(boite[1], y)
          boite[2] = Math.max(boite[2], x); boite[3] = Math.max(boite[3], y)
        }
        for (let q = 0; q < n; q++) if (cum[q] >= s0 - 50 && cum[q] <= s1 + 50) etendre(trace[2 * q], trace[2 * q + 1])
        for (const s of [s0, s1]) { const p = this.situer(route, s); etendre(p[0], p[1]) }
        let largMin = Infinity
        largeurs.forEach(([a, l], q) => {
          const b = q + 1 < largeurs.length ? largeurs[q + 1][0] : Infinity
          if (b > s0 && a < s1) largMin = Math.min(largMin, l)
        })
        return { j, s0, s1, boite, deuxFiles: largMin >= LARGEUR_DEUX_FILES_M }
      })
      return route
    })
  }

  // Les intervalles, recoupés au contour de la Métropole (pas de 5 m) : dehors, les dalles sont découpées et un
  // bateau flotterait sur le fond. Un morceau de moins de 40 m ne porte rien, comme dans le calque.
  recouper(r, intervalles) {
    if (!this.contient) return intervalles
    const res = []
    for (const [s0, s1] of intervalles) {
      let debut = null, avant = s0
      for (let s = s0; ; s = Math.min(s1, s + 5)) {
        const p = this.situer(r, s), dedans = this.contient([p[0], p[1]])
        if (dedans && debut === null) debut = s
        if (debut !== null && (!dedans || s >= s1)) {
          // un bout coupé par le contour recule d'une demi-péniche : le fondu s'achève avant la frange de la découpe
          const a = debut > s0 ? debut + RECUL_CONTOUR_M : debut, b = dedans ? s : avant - RECUL_CONTOUR_M
          if (b - a >= 40) res.push([a, b])
          debut = null
        }
        if (s >= s1) break
        avant = s
      }
    }
    return res
  }

  // La position d'une abscisse s (m) : [x, y px L8, gE, gN dans le sens de la route].
  situer(r, s) {
    const c = r.trace, cum = r.cum
    let lo = 0, hi = cum.length - 1
    while (hi - lo > 1) { const mi = (lo + hi) >> 1; if (cum[mi] <= s) lo = mi; else hi = mi }
    const seg = cum[hi] - cum[lo], u = seg > 0 ? Math.max(0, Math.min(1, (s - cum[lo]) / seg)) : 0
    return [c[2 * lo] + u * (c[2 * hi] - c[2 * lo]), c[2 * lo + 1] + u * (c[2 * hi + 1] - c[2 * lo + 1]), r.dirs[2 * lo], r.dirs[2 * lo + 1]]
  }

  // Distance (m) d'une abscisse à la portion couverte la plus proche ; 0 dedans.
  distanceCouvert(r, s) {
    let d = Infinity
    for (const [a, b] of r.couverts) d = Math.min(d, s < a ? a - s : s > b ? s - b : 0)
    return d
  }

  largeurEn(r, s) {
    let l = r.largeurs[0][1]
    for (const [a, w] of r.largeurs) { if (a > s) break; l = w }
    return l
  }

  // ─── Activité : posé, suspendu ou retiré ──────────────────────────────────────────────────────────────────────
  majActivite() {
    if (this.detruit || !this.routes) return
    if (this.reduit.matches) { this.retirer(); return }
    if (!this.toile) this.poser()
    if (document.hidden || this.carte.getZoom() < NIVEAU_MIN) { this.suspendre(); this.effacer() } else this.reprendre()
  }

  poser() {
    const volet = this.carte.getPane("mobiles") || this.carte.createPane("mobiles")
    volet.style.zIndex = Z_VOLET
    volet.style.pointerEvents = "none"
    this.toile = this.L.DomUtil.create("canvas", "acc-mobiles", volet)
    this.toile.setAttribute("aria-hidden", "true")
    this.ctx = this.toile.getContext("2d")
    this.toileObjet = document.createElement("canvas")
    this.masque = document.createElement("canvas")
    this.masqueCadre = null
    this.carte.on("move", this.surDeplacement)
    this.carte.on("moveend zoomend viewreset", this.surFin)
    this.carte.on("zoomstart", this.surZoomDebut)
    this.carte.on("resize", this.surTaille)
    this.dimensionner()
    this.construireMasque()
  }

  retirer() {
    this.suspendre()
    if (!this.toile) return
    this.carte.off("move", this.surDeplacement)
    this.carte.off("moveend zoomend viewreset", this.surFin)
    this.carte.off("zoomstart", this.surZoomDebut)
    this.carte.off("resize", this.surTaille)
    this.toile.remove()
    this.toile = null
  }

  detruire() {
    this.detruit = true
    this.retirer()
    this.reduit.removeEventListener("change", this.surReduit)
    document.removeEventListener("visibilitychange", this.surVisibilite)
  }

  toileVisible(oui) { if (this.toile) this.toile.style.visibility = oui ? "" : "hidden" }

  dimensionner() {
    const { x, y } = this.carte.getSize(), dpr = window.devicePixelRatio || 1
    this.largeur = x; this.hauteur = y; this.dpr = dpr
    this.toile.width = Math.round(x * dpr); this.toile.height = Math.round(y * dpr)
    this.toile.style.width = `${x}px`; this.toile.style.height = `${y}px`
    this.recaler()
  }

  recaler() {
    if (this.toile) this.L.DomUtil.setPosition(this.toile, this.carte.containerPointToLayerPoint([0, 0]))
  }

  effacer() {
    if (this.ctx) { this.ctx.setTransform(1, 0, 0, 1, 0, 0); this.ctx.clearRect(0, 0, this.toile.width, this.toile.height) }
  }

  reprendre() {
    if (this.image || !this.toile) return
    this.avant = -Infinity
    const pas = (t) => {
      this.image = requestAnimationFrame(pas)
      if (t - this.avant < INTERVALLE_MS) return
      this.avant = t
      this.dessiner(t)
    }
    this.image = requestAnimationFrame(pas)
  }

  suspendre() {
    if (this.image) cancelAnimationFrame(this.image)
    this.image = null
  }

  horloge() { return this.horlogeFigee ?? (performance.now() - this.t0) / 1000 }

  // ─── La carte des codes (propriété, niveau 8) ───────────────────────────────────────────────────────────────
  chargerCode(tx, ty) {
    const cle = tx * 4096 + ty
    let ent = this.codes.get(cle)
    if (ent) return ent.promesse
    ent = { a: null }
    this.codes.set(cle, ent)
    if (this.dallesCodes && !this.dallesCodes.has(`${tx}/${ty}`)) { ent.a = false; ent.promesse = Promise.resolve(); return ent.promesse }
    ent.promesse = lireImage(this.urlCode(`${NIVEAU_REPERE}/${tx}/${ty}`), true).then((im) => {
      const cv = document.createElement("canvas"); cv.width = im.width; cv.height = im.height
      const c = cv.getContext("2d", { willReadFrequently: true }); c.drawImage(im, 0, 0)
      const px = c.getImageData(0, 0, im.width, im.height).data, a = new Uint8Array(im.width * im.height)
      for (let q = 0; q < a.length; q++) a[q] = px[4 * q]
      ent.a = a; ent.w = im.width
    }, () => { ent.a = false })
    return ent.promesse
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

  cadre() {
    const z = this.carte.getZoom(), k = 2 ** (z - NIVEAU_REPERE), b = this.carte.getPixelBounds()
    return { k, niveau: z, ox: -b.min.x, oy: -b.min.y, xmin: b.min.x / k, ymin: b.min.y / k, xmax: b.max.x / k, ymax: b.max.y / k,
             pxParM: this.cam.echelle_px_par_m * k }
  }

  // Le masque des volumes de la vue (élargi de MARGE_MASQUE), refait à chaque fin de déplacement.
  construireMasque() {
    if (!this.toile || this.carte.getZoom() < NIVEAU_MIN) return
    const sc = this.cadre(), Wm = this.largeur + 2 * MARGE_MASQUE, Hm = this.hauteur + 2 * MARGE_MASQUE
    const nx0 = (-MARGE_MASQUE - sc.ox) / sc.k, ny0 = (-MARGE_MASQUE - sc.oy) / sc.k
    const promesses = []
    for (let tx = Math.max(0, Math.floor(nx0 / 256)); tx <= Math.floor((nx0 + Wm / sc.k) / 256); tx++)
      for (let ty = Math.max(0, Math.floor(ny0 / 256)); ty <= Math.floor((ny0 + Hm / sc.k) / 256); ty++) promesses.push(this.chargerCode(tx, ty))
    Promise.all(promesses).then(() => {
      if (!this.toile) return
      const sc2 = this.cadre()
      if (sc2.ox !== sc.ox || sc2.oy !== sc.oy || sc2.k !== sc.k) return // la vue a bougé entre-temps
      const m = this.masque
      m.width = Wm; m.height = Hm
      const c = m.getContext("2d"), im = c.createImageData(Wm, Hm), px = im.data
      for (let y = 0; y < Hm; y++) {
        const ny = Math.floor(ny0 + (y + 0.5) / sc.k)
        if (ny < 0) continue
        const ty = ny >> 8, ly = (ny - (ty << 8))
        let txc = -1, d = null
        for (let x = 0; x < Wm; x++) {
          const nx = Math.floor(nx0 + (x + 0.5) / sc.k)
          if (nx < 0) continue
          const tx = nx >> 8
          if (tx !== txc) { txc = tx; d = this.codes.get(tx * 4096 + ty) }
          if (!d || !d.a) continue
          const v = d.a[ly * d.w + (nx - (tx << 8))]
          if (v === 2 || v === 4) px[4 * (y * Wm + x) + 3] = 255
        }
      }
      c.putImageData(im, 0, 0)
      this.masqueCadre = { ox: sc.ox, oy: sc.oy, k: sc.k }
    })
  }

  // ─── 1. La pose ─────────────────────────────────────────────────────────────────────────────────────────────
  poserBateaux(sc, t) {
    const niveauDalles = sc.niveau >= 9 ? 9 : 8 // au-dessous de 8, les dalles sont réduites du niveau 8
    for (const r of this.routes) r.couverts = r.couvertsParNiveau[niveauDalles]
    const E = this.cam.metre_est_px, N = this.cam.metre_nord_px, liste = []
    const marge = 40 * sc.pxParM
    const bx0 = sc.xmin - marge / sc.k, bx1 = sc.xmax + marge / sc.k, by0 = sc.ymin - marge / sc.k, by1 = sc.ymax + marge / sc.k
    for (const r of this.routes) {
      for (const iv of r.intervalles) {
        const b = iv.boite
        if (b[2] < bx0 || b[0] > bx1 || b[3] < by0 || b[1] > by1) continue
        const Li = iv.s1 - iv.s0, cle = r.i * 64 + iv.j
        const files = iv.deuxFiles ? [1, -1] : [1]
        for (const dir of files) {
          const fi = dir > 0 ? 0 : 1
          const v = VITESSE[r.type] * (0.9 + 0.2 * graineDe(cle, fi, 17))
          const n = Math.floor(DENSITE[r.type] / 1000 * Li + graineDe(cle, fi, 13))
          for (let kk = 0; kk < n; kk++) {
            const choix = this.parType[r.type], mi = choix[Math.floor(graineDe(cle, fi, 400 + kk) * choix.length) % choix.length]
            const M = this.modeles[mi]
            const ph = (kk + 0.6 * (graineDe(cle, fi, 300 + kk) - 0.5)) / n
            const s = iv.s0 + replier(ph * Li + dir * v * t, Li)
            // fondu aux bouts de l'intervalle, et à l'approche d'une portion couverte (sur une demi-longueur + 4 m)
            const alpha = Math.min(1, (s - iv.s0) / FONDU_M, (iv.s1 - s) / FONDU_M, this.distanceCouvert(r, s) / (M.L / 2 + 4))
            if (alpha <= 0.02 && !this.garderInvisibles) continue // crochet d'instrument : la planche cherche aussi les effacés
            const p = this.situer(r, s), larg = this.largeurEn(r, s)
            const decal = files.length === 2 ? Math.max(0, Math.min(larg / 4, larg / 2 - M.W / 2 - 0.5)) : 0
            const gE = p[2] * dir, gN = p[3] * dir, dE = gN, dN = -gE // tribord : à droite du sens de marche
            const cx = p[0] + (E[0] * dE + N[0] * dN) * decal, cy = p[1] + (E[1] * dE + N[1] * dN) * decal
            const X = sc.ox + cx * sc.k, Y = sc.oy + cy * sc.k
            if (X < -marge || X > this.largeur + marge || Y < -marge || Y > this.hauteur + marge) continue
            liste.push({ X, Y, gE, gN, M, r, s, s0: iv.s0, s1: iv.s1, dir, decal, v, larg, alpha })
          }
        }
      }
    }
    liste.sort((a, b) => a.Y - b.Y)
    return liste
  }

  // ─── 2. Le sillage : largeur 1, bout rond (chemin rapide du canevas) ─────────────────────────────────────────
  tracerSillages(ctx, sc, liste) {
    const chemins = Array.from({ length: CRANS }, () => new Path2D())
    const E = this.cam.metre_est_px, N = this.cam.metre_nord_px, k = sc.k
    let segments = 0
    for (const b of liste) {
      const M = b.M, L2 = M.L / 2, W2 = M.W / 2
      const fondu = Math.round((1 - b.alpha) * CRANS) // un bateau qui s'efface pâlit son sillage d'autant de crans
      if (fondu >= CRANS) continue
      const S = (0.9 * M.L + 6) * Math.min(2, Math.sqrt(b.v)), J = Math.max(2, Math.round(S / PAS_M)), borne = b.larg / 2 - 0.3
      for (let ligne = 0; ligne < 3; ligne++) {
        let prec = null
        for (let j = 0; j <= J; j++) {
          const d = L2 + j * S / J, s = b.s - b.dir * d
          if (s < b.s0 || s > b.s1 || this.distanceCouvert(b.r, s) === 0) { prec = null; continue }
          let lat = 0
          if (ligne < 2) {
            const sg = ligne === 0 ? -1 : 1
            lat = sg * (W2 * 0.9 + OUVERTURE * (d - L2))
            if (Math.abs(b.decal + lat) > borne) lat = sg * Math.max(0, borne - sg * b.decal) // le bras s'arrête à la berge
          }
          const p = this.situer(b.r, s), gE = p[2] * b.dir, gN = p[3] * b.dir, o = b.decal + lat
          const q = [sc.ox + (p[0] + (E[0] * gN - N[0] * gE) * o) * k, sc.oy + (p[1] + (E[1] * gN - N[1] * gE) * o) * k]
          if (prec) {
            const cr = Math.min(CRANS - 1, Math.floor((j - 1) / J * CRANS) + (ligne === 2 ? 1 : 0)) + fondu
            if (cr < CRANS) { chemins[cr].moveTo(prec[0], prec[1]); chemins[cr].lineTo(q[0], q[1]); segments++ }
          }
          prec = q
        }
      }
      const ga = b.gE, gn = b.gN
      const ax = (E[0] * ga + N[0] * gn) * k, ay = (E[1] * ga + N[1] * gn) * k, bx = (E[0] * gn - N[0] * ga) * k, by = (E[1] * gn - N[1] * ga) * k
      const ar = L2 - Math.min(3, M.L / 4)
      for (const sg of [-1, 1]) {
        chemins[fondu].moveTo(b.X + ax * (L2 + 0.2), b.Y + ay * (L2 + 0.2))
        chemins[fondu].lineTo(b.X + ax * ar + bx * sg * (W2 + 0.5), b.Y + ay * ar + by * sg * (W2 + 0.5))
        segments++
      }
    }
    ctx.save()
    ctx.lineWidth = 1; ctx.lineCap = "round"
    for (let c = 0; c < CRANS; c++) {
      ctx.strokeStyle = `rgba(${SILLAGE_RGB},${(0.85 * (1 - c / CRANS)).toFixed(3)})`
      ctx.stroke(chemins[c])
    }
    ctx.restore()
    return segments // relevé sur ce qui est tracé
  }

  // ─── 4. Un bateau : le sprite du cap le plus proche, masqué colonne par colonne ──────────────────────────────
  //  Dans une colonne, si le pixel juste au-dessus du bas de l'emprise montre un volume (pont, arbre), on masque
  //  la caisse sur la nappe continue de volume qui monte de là (règle des colonnes de pitch60-v1 y33).
  peindreBateau(ctx, sc, b) {
    const sp = this.sprites, n = sp.caps, a = Math.atan2(b.gE, b.gN) * 180 / Math.PI // relèvement de grille de l'étrave
    const ci = ((Math.round(a / (360 / n)) % n) + n) % n, s = sp.index[b.M.cle][ci]
    const f = sc.k / sp.echelle_sprite_par_px_mosaique_L8, dpr = this.dpr
    const E = this.cam.metre_est_px, N = this.cam.metre_nord_px, k = sc.k
    const ax = (E[0] * b.gE + N[0] * b.gN) * k, ay = (E[1] * b.gE + N[1] * b.gN) * k
    const bx = (E[0] * b.gN - N[0] * b.gE) * k, by = (E[1] * b.gN - N[1] * b.gE) * k
    const A = b.M.L / 2, B = b.M.W / 2
    const coins = [[A, B], [A, -B], [-A, -B], [-A, B]].map(([u, w]) => [b.X + ax * u + bx * w, b.Y + ay * u + by * w])
    const x0 = Math.floor(b.X - s[4] * f) - 1, y0 = Math.floor(b.Y - s[5] * f) - 1
    const x1 = Math.ceil(b.X + (s[2] - s[4]) * f) + 1, y1 = Math.ceil(b.Y + (s[3] - s[5]) * f) + 1
    const W = Math.ceil((x1 - x0) * dpr), H = Math.ceil((y1 - y0) * dpr), to = this.toileObjet
    if (to.width < W) to.width = W
    if (to.height < H) to.height = H
    const c = to.getContext("2d")
    c.setTransform(1, 0, 0, 1, 0, 0); c.globalCompositeOperation = "source-over"; c.clearRect(0, 0, W, H)
    c.setTransform(dpr, 0, 0, dpr, -x0 * dpr, -y0 * dpr)
    c.drawImage(this.atlas, s[0], s[1], s[2], s[3], b.X - s[4] * f, b.Y - s[5] * f, s[2] * f, s[3] * f)
    c.globalCompositeOperation = "destination-out"; c.fillStyle = "#000"
    for (let x = x0; x < x1; x++) {
      const xc = x + 0.5, nx = (xc - sc.ox) / k
      let bas = -Infinity
      for (let e = 0; e < 4; e++) {
        const p = coins[e], q = coins[(e + 1) & 3]
        if ((p[0] - xc) * (q[0] - xc) > 0 || p[0] === q[0]) continue
        bas = Math.max(bas, p[1] + (q[1] - p[1]) * (xc - p[0]) / (q[0] - p[0]))
      }
      if (bas === -Infinity) continue
      const y = Math.floor(bas - 0.5)
      if (estVolume(this.codeEn(nx, (y + 0.5 - sc.oy) / k))) {
        let haut = y
        while (haut - 1 >= y0 && estVolume(this.codeEn(nx, (haut - 0.5 - sc.oy) / k))) haut--
        c.fillRect(x, haut, 1, y1 - haut)
      }
    }
    ctx.globalAlpha = b.alpha
    ctx.drawImage(to, 0, 0, W, H, x0, y0, W / dpr, H / dpr)
    ctx.globalAlpha = 1
  }

  dessiner(tms) {
    const j0 = performance.now(), sc = this.cadre(), ctx = this.ctx, dpr = this.dpr
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, this.toile.width, this.toile.height)
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    const liste = this.poserBateaux(sc, this.horloge())
    const segments = this.tracerSillages(ctx, sc, liste)
    const mc = this.masqueCadre, masque = Boolean(mc && mc.k === sc.k)
    if (masque) {
      ctx.save(); ctx.globalCompositeOperation = "destination-out"
      ctx.drawImage(this.masque, sc.ox - mc.ox - MARGE_MASQUE, sc.oy - mc.oy - MARGE_MASQUE)
      ctx.restore()
    }
    let peints = 0
    for (const b of liste) { this.peindreBateau(ctx, sc, b); peints++ } // relevé où le bateau est peint
    const js = performance.now() - j0
    this.stats = { peints, segments, js, niveau: sc.niveau, masque }
    if (this.banc) { this.banc.instants.push(tms); this.banc.js.push(js); this.banc.peints.push(peints); this.banc.segments.push(segments) }
  }
}
