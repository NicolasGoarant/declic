// La page d'accueil sur la carte (/labo/accueil), portée de maquette-declic-v3 (nancy-3d).
//
// Deux fonds, au choix dans le panneau « Calques » : le diorama (mosaïque axonométrique, CRS.Simple)
// et le plan (OpenStreetMap, Web Mercator). La bascule recrée la carte Leaflet au même endroit
// (centre et zoom d'échelle équivalente, par diorama_projection) ; les marqueurs, bouquets, popups,
// filtres et le volet ne connaissent que `p.latlng`, recalculé pour chaque fond par poserPoints.
//
// Leaflet est importé À LA DEMANDE, dans connect() : ce contrôleur est chargé d'office sur toutes
// les pages (eagerLoadControllersFrom), et les autres pages n'ont pas à tirer le CDN. Les pins
// proches se regroupent en bouquets (diorama/bouquets), sans Leaflet.markercluster.
import { Controller } from "@hotwired/stimulus"
import { creerProjection } from "diorama_projection"
import { creerCoucheDalles, creerCoucheBlanche } from "diorama/couches"
import { creerCoucheAmbiance, lireAmbiance, uniformesEtat } from "diorama/ambiance"
import { momentAuto, saisonAuto, libelleAuto } from "diorama/soleil"
import { meteoAuto, meteoGardee } from "diorama/meteo"
import { Precipitations } from "diorama/precipitations"
import { chargerLampadaires, compterLampadaires } from "diorama/lampadaires"
import { LAMPADAIRES, PINS } from "diorama/reglages"
import { regrouper, eventail, FLEURS_MAX, respiration, echelleIcone, dispositionPin } from "diorama/bouquets"
import { chargerContour, creerDecoupe, poserSocle } from "diorama/contour"
import {
  CLE_FOND, CLE_AMBIANCE, CLE_AUTO, CLES_REGLAGES, CLE_BLANCHE, CLE_STYLE, lire, ecrire, fondDeDepart, styleDeDepart
} from "diorama/preferences"
import { lireDate, aujourdhui, estPasse, estAVenir, dansLaFenetre, etiquette, periode, jourCourt } from "diorama/dates"

const NIVEAU_MAX = 8
// Au-delà de ce nombre d'échecs consécutifs sur des dalles pourtant listées, une trace (dev
// seulement) : un pan de la pyramide publiée sur R2 pour ce style, à repérer avant qu'un dézoom
// ne tombe dedans (voir DioramaTuiles, « même grille, mêmes niveaux »).
const ECHECS_CONSECUTIFS_TRACE = 6
// Vue initiale, à retoucher ici : place Stanislas (WGS84) et niveau de zoom Leaflet du diorama (0-8,
// 8 = pleine résolution) ; le plan prend le zoom d'échelle équivalente. Ajouter ?debug_vue=1 à l'URL
// affiche en direct le centre et le zoom courants.
const CENTRE_INITIAL = { lat: 48.6936, lon: 6.1833 }
const ZOOM_INITIAL = 6
const ZOOM_PLAN_INITIAL = 16 // ≈ ZOOM_INITIAL du diorama (zoomPlan), quand le diorama manque
const ATTRIBUTION = "IGN BD TOPO®, BD ORTHO® et LiDAR HD (LO 2.0) · Métropole du Grand Nancy, Géonancy · " +
                    "© les contributeurs OpenStreetMap (ODbL)"
// Le plan : le fond OpenStreetMap de l'ancienne page d'accueil (shared/_map), avec son attribution.
const PLAN = {
  url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">les contributeurs OpenStreetMap</a>',
  minZoom: 10, maxZoom: 19
}
// Les valeurs de chaque réglage d'ambiance ; la première est l'image d'origine. Les étalonnages
// publiés (PUBLIEES) ne sont proposés que s'ils répondent sur le domaine des tuiles.
const REGLAGES = {
  moment: ["jour", "aube", "heure-doree", "heure-bleue", "nuit"],
  saison: ["printemps-ete", "automne", "hiver"],
  meteo: ["clair", "pluie", "neige"]
}
const PUBLIEES = ["heure-bleue", "automne", "hiver"]
const NEUTRE = { moment: "jour", saison: "printemps-ete", meteo: "clair" }
const FICHES_MAX = 24
const HISTOIRES = "histoires" // Categorie::HISTOIRES : les Belles Histoires
const CLE_FAVORIS = "declic:favoris"
const ETROIT = "(max-width: 699.98px)"

// Texte noir ou blanc selon la clarté de la couleur de catégorie (luminance relative WCAG).
function encreSur(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? "#1d1a2b" : "#ffffff"
}

export default class extends Controller {
  // mini : petite carte d'une fiche (un seul point, sans volet ni commandes, voir demarrerMini).
  static values = { points: Array, categories: Array, tuiles: Object, developpement: Boolean, mini: Boolean }
  static targets = [
    "carte", "alerte", "voletTitre", "poigneeTitre", "compteur", "fiches", "vide", "stats",
    "modeleFiche", "modelePin", "modelePopup", "categorie", "ongletFavoris", "ongletCarte",
    "boutonCalques", "panneauCalques", "voileCalques", "choixFond", "rubriqueAmbiance", "choixAuto",
    "choixReglage", "choixBlanche", "ambianceAuto", "rubriqueStyle", "choixStyle"
  ]

  connect() {
    this.categoriesParCle = Object.fromEntries(this.categoriesValue.map((c) => [c.cle, c]))
    this.appliquerReglagesPins()
    if (this.miniValue) { this.demarrerMini(); return }
    this.filtre = { categories: new Set(), favoris: false }
    this.favoris = this.lireFavoris()
    this.selection = null
    this.points = this.pointsValue.map((p) => ({ ...p, debut: lireDate(p.debut), fin: lireDate(p.fin) }))
    this.categorieTargets.forEach((b) => b.style.setProperty("--c", this.categoriesParCle[b.dataset.cle]?.couleur))
    this.majCompteurs()
    this.majVolet()
    this.demarrer()
    // Onglet Favoris des fiches (/labo/accueil?favoris=1). Après la connexion du volet, qui écoute
    // l'événement d'ouverture.
    if (new URLSearchParams(window.location.search).get("favoris") === "1") setTimeout(() => this.basculerFavoris())
  }

  disconnect() {
    clearInterval(this.minuterieAuto)
    this.precipitations?.detruire()
    this.observateur?.disconnect()
    window.removeEventListener("orientationchange", this.surOrientation)
    this.ecranEtroit?.removeEventListener("change", this.surEcranEtroit)
    this.carte?.remove()
    this.carte = null
  }

  // ─── Pins et bouquets : tailles et temps (diorama/reglages.js#PINS), une seule fois ─────
  // Écrits en variables CSS pour que reglages.js reste l'unique source (accueil.css ne fait que
  // les consommer). --icone-echelle (par catégorie) et les temps de respiration (par pin) restent
  // posés au cas par cas, sur chaque marqueur (iconePin, bouquet).
  appliquerReglagesPins() {
    const s = this.element.style
    s.setProperty("--taille-icone-bureau", `${PINS.hauteur_px.large}px`)
    s.setProperty("--taille-icone-mobile", `${PINS.hauteur_px.etroit}px`)
    s.setProperty("--tige-longueur", `${PINS.tige_longueur_px}px`)
    s.setProperty("--pin-recouvrement", `${PINS.recouvrement_px}px`)
    s.setProperty("--pin-respire-amplitude", `${PINS.respiration.amplitude_px}px`)
    s.setProperty("--pin-survol-echelle", PINS.survol.echelle)
    s.setProperty("--pin-survol-elevation", `${PINS.survol.elevation_px}px`)
    s.setProperty("--pin-selection-echelle", PINS.selection.echelle)
    s.setProperty("--pin-selection-duree", `${PINS.selection.duree_ms}ms`)
    s.setProperty("--pin-onde-duree", `${PINS.selection.onde_duree_ms}ms`)
    s.setProperty("--pin-apparition-duree", `${PINS.apparition.duree_ms}ms`)
    s.setProperty("--pin-rdv-periode", `${PINS.rendezVousJour.periode_s}s`)
  }

  etroitEcran() { return window.matchMedia(ETROIT).matches }

  // ─── Petite carte d'une fiche ────────────────────────────────────────────────────────
  // Elle suit le fond choisi sur la carte. Diorama, et point dans son emprise (sur une dalle
  // publiée, dans la Métropole) : le diorama, figé, pin de la catégorie au centre. Sinon : le plan.
  async demarrerMini() {
    const p = this.pointsValue[0]
    if (!p || !Number.isFinite(p.latitude) || !Number.isFinite(p.longitude)) return
    try {
      const module = await import("leaflet")
      this.L = module.default ?? module
    } catch (erreur) {
      console.error("carte :", erreur)
      return
    }
    let pixel = null
    if (this.tuilesValue.disponibles?.vrai && fondDeDepart() === "diorama") {
      this.style = styleDeDepart(this.tuilesValue.disponibles.styles || [])
      try {
        const contour = this.chargerContour()
        await this.chargerManifeste()
        this.preparerDecoupe(await contour)
        pixel = this.pixelDansLeDiorama(p)
      } catch (erreur) {
        console.warn("diorama indisponible, fond OpenStreetMap :", erreur)
      }
    }
    if (!this.carteTarget.isConnected) return
    if (pixel) this.miniDiorama(p, pixel)
    else this.miniPlan(p)
    this.suivreTaille()
  }

  // Gardé par style : chaque style a son propre plancher de niveaux publiés (voir majZoomMin),
  // pas seulement son propre grade de dalles ("même grille, mêmes niveaux" ne tient plus tant que
  // jeu-video-v1 n'a pas sa pyramide complète, cf. rapport dézoom).
  async chargerManifeste() {
    const t = this.tuilesValue
    this.manifestes ??= {}
    if (!this.manifestes[this.style]) {
      const reponse = await fetch(`${t.base}/${this.style}/manifeste.json`)
      if (!reponse.ok) throw new Error(`manifeste HTTP ${reponse.status}`)
      this.manifestes[this.style] = await reponse.json()
    }
    this.manifeste = this.manifestes[this.style]
    this.projection = creerProjection(this.manifeste)
    this.dallesListees = this.indexerDalles(this.manifeste)
  }

  // Pixel du point dans la mosaïque (niveau 8), ou null hors couverture : hors de la mosaïque, sur
  // une dalle vide ou hors du contour de la Métropole (même règle pour la carte et la mini-carte).
  pixelDansLeDiorama(p) {
    const [x, y] = this.projection.versL93(p.longitude, p.latitude)
    const px = this.projection.pixelL93(x, y)
    if (!this.projection.dansLaMosaique(px)) return null
    if (this.decoupe && !this.decoupe.contient(px)) return null
    return this.dallesListees[NIVEAU_MAX]?.has(`${Math.floor(px[0] / 256)}/${Math.floor(px[1] / 256)}`) ? px : null
  }

  // Le contour de la Métropole (diorama/contour) ; sans lui, le diorama s'affiche sur sa grille de dalles.
  chargerContour() {
    return chargerContour().catch((erreur) => { console.warn("diorama : contour indisponible", erreur); return null })
  }

  preparerDecoupe(anneau) {
    this.decoupe = anneau ? creerDecoupe(anneau, this.projection) : null
  }

  // Emprise du contour (ou de la mosaïque) en coordonnées Leaflet.
  bornesContour() {
    if (!this.decoupe) return this.bornes
    const [x0, y0, x1, y1] = this.decoupe.emprise
    return this.L.latLngBounds(this.carte.unproject([x0, y1], NIVEAU_MAX), this.carte.unproject([x1, y0], NIVEAU_MAX))
  }

  // Les dalles d'une couche, découpées au contour ; le socle et l'ombre dessous.
  decouper(couche) { return this.decoupe ? this.decoupe.decouper(couche) : couche }

  poserSocle() { if (this.decoupe) poserSocle(this.L, this.carte, this.decoupe.pixels) }

  optionsFigees() {
    return {
      zoomControl: false, dragging: false, touchZoom: false, scrollWheelZoom: false, doubleClickZoom: false,
      boxZoom: false, keyboard: false
    }
  }

  miniDiorama(p, pixel) {
    const L = this.L
    this.carte = L.map(this.carteTarget, { crs: L.CRS.Simple, minZoom: 0, maxZoom: NIVEAU_MAX, attributionControl: false, ...this.optionsFigees() })
    this.preparerCouchesDiorama(NIVEAU_MAX)
    this.poserAttribution()
    this.poserSocle()
    this.poserCoucheFond(this.coucheVraie())
    const latlng = this.carte.unproject(L.point(pixel[0], pixel[1]), NIVEAU_MAX)
    this.poserPinMini(p, latlng, NIVEAU_MAX - 1)
  }

  miniPlan(p) {
    const L = this.L
    this.carte = L.map(this.carteTarget, { attributionControl: false, ...this.optionsFigees() })
    this.poserAttribution()
    this.couchePlan().addTo(this.carte)
    this.poserPinMini(p, L.latLng(p.latitude, p.longitude), 15)
  }

  // Le pin, ancré au pied : on descend la vue pour que le pictogramme soit au centre.
  poserPinMini(p, latlng, zoom) {
    this.L.marker(latlng, { icon: this.iconePin(p), title: p.titre, interactive: false, keyboard: false }).addTo(this.carte)
    this.carte.setView(latlng, zoom, { animate: false })
    const { icone } = dispositionPin(this.etroitEcran())
    this.carte.panBy([0, -icone], { animate: false })
  }

  // ─── Démarrage : bibliothèques, manifeste, projection, carte ─────────────────────────
  // Sans diorama (non publié, ou manifeste illisible), la carte démarre sur le plan.
  async demarrer() {
    const t = this.tuilesValue
    this.dioramaDispo = Boolean(t.disponibles?.vrai)
    this.style = this.dioramaDispo ? styleDeDepart(t.disponibles.styles || []) : null
    const contour = this.dioramaDispo ? this.chargerContour() : null
    try {
      const module = await import("leaflet")
      this.L = module.default ?? module
    } catch (erreur) {
      console.error("carte :", erreur)
      this.alerter("La carte n'a pas pu se charger. Les initiatives restent listées ci-dessous.")
      return
    }
    if (this.dioramaDispo) {
      try {
        // Les masques se lisent avant la carte : sans leur liste de dalles, on demanderait des dalles absentes (404).
        const [, masque, arbres] = await Promise.all([
          this.chargerManifeste(), t.disponibles.blanche ? this.chargerListe(t.masque) : null,
          t.disponibles.arbres ? this.chargerListe(t.arbres) : null
        ])
        Object.assign(this, { dallesMasque: masque, dallesArbres: arbres })
        this.preparerDecoupe(await contour)
      } catch (erreur) {
        console.error("diorama :", erreur)
        this.dioramaDispo = false
        this.alerter("Le diorama n'a pas pu se charger : voici le plan.")
      }
    }
    if (!this.carteTarget.isConnected) return
    this.fond = this.dioramaDispo ? fondDeDepart() : "plan"
    this.lireReglages()
    this.construireCarte()
    this.vueInitiale()
    this.majCalques()
    if (this.dioramaDispo) {
      // Automatique : le soleil bouge, la météo se renouvelle (appel gardé 30 minutes).
      this.minuterieAuto = setInterval(() => { if (this.auto) this.rafraichirAuto() }, 60000)
      if (this.auto) this.rafraichirAuto()
    }
  }

  indexerDalles(manifeste) {
    return Object.fromEntries(Object.entries(manifeste.dalles || {})
      .map(([z, liste]) => [z, new Set(liste.map(([x, y]) => `${x}/${y}`))]))
  }

  // La carte du fond courant, ses couches, puis la couche de marqueurs (commune aux deux fonds).
  construireCarte() {
    const L = this.L
    if (this.fond === "diorama") this.creerDiorama()
    else this.creerPlan()
    this.element.dataset.fond = this.fond

    this.calquePins = L.layerGroup().addTo(this.carte)
    this.carte.on("zoomend", () => this.dessinerPins())
    this.carte.on("moveend", () => this.majVolet())
    this.carte.on("click", () => {
      this.selectionner(null)
      this.dispatch("carte-cliquee") // la bottom sheet se replie
    })
    // Respiration et lueurs suspendues pendant le déplacement/zoom (data-mouvement, accueil.css).
    this.carte.on("movestart zoomstart", () => { this.element.dataset.mouvement = "1" })
    this.carte.on("moveend zoomend", () => { delete this.element.dataset.mouvement })
    this.brancherDebugVue()
    this.brancherEcranEtroit()
    this.poserPoints()
    this.appliquerFiltres()
    this.suivreTaille()
    this.majMeteo()
  }

  // La taille visible d'un pin dépend du seuil ETROIT (largeur d'écran), pas du zoom : si on le
  // franchit en direct (rotation, redimensionnement), les marqueurs déjà posés sont refaits pour
  // que la géométrie Leaflet (iconSize, iconAnchor) suive la nouvelle taille CSS.
  brancherEcranEtroit() {
    if (this.ecranEtroit) return
    this.ecranEtroit = window.matchMedia(ETROIT)
    this.surEcranEtroit = () => {
      this.points.forEach((p) => { p.marqueur = null })
      this.dessinerPins()
    }
    this.ecranEtroit.addEventListener("change", this.surEcranEtroit)
  }

  creerDiorama() {
    const L = this.L
    const plafond = window.matchMedia(ETROIT).matches ? NIVEAU_MAX : NIVEAU_MAX + 1
    this.carte = L.map(this.carteTarget, {
      crs: L.CRS.Simple, minZoom: 0, maxZoom: plafond, zoomSnap: 1,
      zoomControl: false, attributionControl: false
    })
    this.preparerCouchesDiorama(NIVEAU_MAX + 1)
    // On ne sort pas de la table : la Métropole et une marge autour, sans élasticité au bord.
    this.carte.setMaxBounds(this.bornesContour().pad(0.25))
    this.carte.options.maxBoundsViscosity = 0.95
    this.majZoomMin()
    this.carte.fitBounds(this.bornesContour()) // une vue d'abord : le regroupement en bouquets en a besoin
    this.poserAttribution()
    this.poserSocle()
    this.poserCoucheFond(this.coucheCourante())
  }

  creerPlan() {
    this.carte = this.L.map(this.carteTarget, {
      minZoom: PLAN.minZoom, maxZoom: PLAN.maxZoom, zoomSnap: 1, zoomControl: false, attributionControl: false
    })
    this.carte.setView([CENTRE_INITIAL.lat, CENTRE_INITIAL.lon], ZOOM_PLAN_INITIAL) // une vue d'abord, comme au diorama
    this.poserAttribution()
    this.couchePlan().addTo(this.carte)
  }

  couchePlan() {
    return this.L.tileLayer(PLAN.url, { maxZoom: PLAN.maxZoom, attribution: PLAN.attribution })
  }

  // Emprise de la mosaïque et options des couches de dalles, pour une carte diorama neuve.
  preparerCouchesDiorama(zoomMax) {
    const [largeur, hauteur] = this.manifeste.taille_mosaique_px
    this.bornes = this.L.latLngBounds(this.carte.unproject([0, hauteur], NIVEAU_MAX), this.carte.unproject([largeur, 0], NIVEAU_MAX))
    this.optionsCouche = {
      minZoom: 0, maxZoom: zoomMax, maxNativeZoom: NIVEAU_MAX, tileSize: 256,
      noWrap: true, bounds: this.bornes, attribution: ATTRIBUTION
    }
    this.couches = {}
    this.coucheFond = null
  }

  // La carte occupe tout l'écran (100dvh moins la tab bar) : sa taille change avec la barre d'URL
  // mobile, la rotation ou le redimensionnement, et Leaflet doit recalculer sa surface à chaque fois.
  // Branché une fois : les cartes successives (bascule de fond) partagent le même conteneur.
  suivreTaille() {
    if (this.observateur) return
    const recalculer = () => {
      this.carte?.invalidateSize()
      if (!this.miniValue) this.majZoomMin()
    }
    this.observateur = new ResizeObserver(recalculer)
    this.observateur.observe(this.carteTarget)
    this.surOrientation = () => setTimeout(recalculer, 200) // les dimensions se stabilisent après l'événement
    window.addEventListener("orientationchange", this.surOrientation)
    requestAnimationFrame(recalculer)
  }

  // Au dézoom maximal, la Métropole entière tient dans la partie visible de la carte (hors logo et
  // volet) — sans dépasser le plancher réellement publié pour le style courant (niveau_min du
  // manifeste) : en dessous, ses dalles ne sont pas listées et le diorama se viderait sans erreur.
  majZoomMin() {
    if (!this.carte || this.fond !== "diorama") return
    const { haut, bas } = this.marges()
    const zoom = this.carte.getBoundsZoom(this.bornesContour(), false, this.L.point(2 * 16, haut + bas))
    const plancherStyle = this.manifeste?.niveau_min ?? 0
    this.carte.setMinZoom(Math.max(0, plancherStyle, Math.min(zoom, NIVEAU_MAX - 1)))
  }

  // L'attribution est obligatoire (licences IGN, Géonancy, OSM) : repliée en « ⓘ », elle
  // se déplie au toucher.
  poserAttribution() {
    const controle = this.L.control.attribution({ prefix: false, position: "bottomleft" }).addTo(this.carte)
    const el = controle.getContainer()
    el.classList.add("acc-attribution")
    el.tabIndex = 0
    el.setAttribute("role", "button")
    el.setAttribute("aria-label", "Sources et licences de la carte")
    el.setAttribute("aria-expanded", "false")
    const basculer = (e) => {
      e.stopPropagation()
      const ouverte = el.classList.toggle("acc-attribution--ouverte")
      el.setAttribute("aria-expanded", String(ouverte))
    }
    this.L.DomEvent.disableClickPropagation(el)
    el.addEventListener("click", basculer)
    el.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); basculer(e) } })
  }

  // ─── Bascule Diorama / Plan ──────────────────────────────────────────────────────────
  choisirFond(event) {
    this.changerFond(event.target.value)
  }

  // Recrée la carte sur l'autre fond, au même endroit. Le choix est gardé sur l'appareil.
  changerFond(fond) {
    if (!this.carte || fond === this.fond || (fond === "diorama" && !this.dioramaDispo)) { this.majCalques(); return }
    const vue = this.vueGeo()
    this.fermerPopup()
    this.precipitations?.detruire()
    this.precipitations = null
    this.carte.remove()
    this.popup = null
    this.fond = fond
    ecrire(CLE_FOND, fond)
    this.construireCarte()
    this.poserVueGeo(vue)
    this.majCalques()
  }

  // Centre (WGS84, au sol) et zoom du plan d'échelle équivalente à la vue courante.
  vueGeo() {
    const c = this.carte.getCenter(), z = this.carte.getZoom()
    if (this.fond === "plan") return { lat: c.lat, lon: c.lng, zoomPlan: z }
    const { x, y } = this.carte.project(c, NIVEAU_MAX)
    const [lon, lat] = this.projection.versWGS84(x, y)
    return { lat, lon, zoomPlan: this.projection.zoomPlan(z, lat) }
  }

  poserVueGeo({ lat, lon, zoomPlan }) {
    if (this.fond === "plan") {
      this.carte.setView([lat, lon], Math.round(zoomPlan), { animate: false })
      return
    }
    const [px, py] = this.projection.pixel(lat, lon)
    const zoom = Math.round(this.projection.zoomDiorama(zoomPlan, lat))
    this.carte.setView(this.carte.unproject(this.L.point(px, py), NIVEAU_MAX), zoom, { animate: false })
  }

  // ─── Bascule du style du diorama (Réaliste / Jeu vidéo) ──────────────────────────────
  // Mêmes dalles, même grille : on garde la carte (centre, zoom, marqueurs, volet, ambiance en
  // cours) et on ne recrée que la couche de fond. Les couches sont gardées par état (this.couches :
  // « vrai », « blanche », un par combinaison d'ambiance) et leur canevas est calculé pour le style
  // qui était actif ; on les jette toutes pour que la nouvelle couche de fond se recalcule dans le
  // style choisi (« caches d'étalonnage par dalle » invalidés).
  choisirStyle(event) {
    this.changerStyle(event.target.value)
  }

  changerStyle(style) {
    if (!this.carte || style === this.style || !this.tuilesValue.disponibles?.styles?.includes(style)) {
      this.majCalques()
      return
    }
    const precedent = this.style
    this.style = style
    // Chaque style a son propre manifeste (dalles listées, plancher de niveaux) : on le recharge
    // avant de reposer la couche, sinon estListee filtrerait le nouveau style avec l'ancien.
    this.chargerManifeste().then(() => {
      ecrire(CLE_STYLE, style)
      this.couches = {}
      this.majZoomMin()
      if (this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
      this.majCalques()
    }).catch((erreur) => {
      console.error("diorama : style indisponible", erreur)
      this.style = precedent
      this.majCalques()
    })
  }

  // ─── Le panneau « Calques » ──────────────────────────────────────────────────────────
  basculerCalques() {
    if (this.panneauCalquesTarget.hidden) this.ouvrirCalques()
    else this.fermerCalques()
  }

  ouvrirCalques() {
    this.fermerPopup()
    this.majCalques()
    this.panneauCalquesTarget.hidden = false
    this.voileCalquesTarget.hidden = false
    this.boutonCalquesTarget.setAttribute("aria-expanded", "true")
    this.panneauCalquesTarget.querySelector("input:checked:not(:disabled), input:not(:disabled)")?.focus()
  }

  fermerCalques() {
    if (!this.hasPanneauCalquesTarget || this.panneauCalquesTarget.hidden) return
    const focusDedans = this.panneauCalquesTarget.contains(document.activeElement)
    this.panneauCalquesTarget.hidden = true
    this.voileCalquesTarget.hidden = true
    this.boutonCalquesTarget.setAttribute("aria-expanded", "false")
    if (focusDedans) this.boutonCalquesTarget.focus()
  }

  // Les commandes du panneau reflètent l'état de la carte.
  majCalques() {
    this.choixFondTargets.forEach((c) => {
      c.checked = c.value === this.fond
      c.disabled = c.value === "diorama" && !this.dioramaDispo
      c.closest("label").title = c.disabled ? "Diorama momentanément indisponible" : ""
    })
    if (this.hasRubriqueAmbianceTarget) this.rubriqueAmbianceTarget.hidden = this.fond !== "diorama"
    if (this.hasRubriqueStyleTarget) this.rubriqueStyleTarget.hidden = this.fond !== "diorama"
    this.choixStyleTargets.forEach((c) => { c.checked = c.value === this.style })
    // Les réglages affichés : ceux qu'« Automatique » retient, sinon ceux choisis.
    const etat = this.etatAffiche()
    if (this.hasChoixAutoTarget) this.choixAutoTarget.checked = this.auto
    this.choixReglageTargets.forEach((c) => { c.checked = c.value === etat[c.dataset.reglage] })
    if (this.hasChoixBlancheTarget) this.choixBlancheTarget.checked = this.rendu === "blanche"
    if (this.hasAmbianceAutoTarget) this.ambianceAutoTarget.textContent = this.auto ? ` : ${libelleAuto(etat)}` : ""
  }

  // ─── Les couches de fond du diorama ──────────────────────────────────────────────────
  url(dossier, chemin) { return `${this.tuilesValue.base}/${dossier}/${chemin}` }

  // Une dalle publiée, et pas entièrement hors du contour de la Métropole.
  estListee = (coords) =>
    (this.dallesListees[coords.z]?.has(`${coords.x}/${coords.y}`) ?? false) && this.decoupe?.etat(coords) !== "dehors"

  masqueListe = (coords) => {
    if (coords.z < 6 || coords.z > NIVEAU_MAX) return false
    return this.dallesMasque ? (this.dallesMasque[coords.z]?.has(`${coords.x}/${coords.y}`) ?? false) : true
  }

  // Repère un pan de pyramide sans le publier lui-même : après ECHECS_CONSECUTIFS_TRACE échecs de
  // suite sur des dalles listées (donc réellement demandées, pas simplement absentes du manifeste),
  // une trace unique en développement. Les dalles non listées ne comptent pas : elles ne partent
  // jamais en requête (couches.js, tuileVide).
  surveillerEchecs(couche) {
    if (!this.developpementValue) return couche
    let suite = 0
    let averti = false
    couche.on("tileload", () => { suite = 0 })
    couche.on("tileerror", ({ coords }) => {
      suite++
      if (averti || suite < ECHECS_CONSECUTIFS_TRACE) return
      averti = true
      console.warn(
        `diorama : ${suite} dalles consécutives en échec (style « ${this.style} », niveau ${coords.z}) — `
        + "pyramide de tuiles probablement trouée sur R2 pour ce niveau."
      )
    })
    return couche
  }

  // Dalles publiées d'une couche annexe (masque du bâti, des arbres, lumières), d'après son manifeste ;
  // null si illisible.
  async chargerListe(dossier) {
    try {
      const reponse = await fetch(this.url(dossier, "manifeste.json"))
      if (reponse.ok) {
        const manifeste = await reponse.json()
        if (manifeste.dalles) return this.indexerDalles(manifeste)
      }
    } catch (erreur) {
      console.warn(`diorama : manifeste ${dossier} illisible`, erreur)
    }
    return null
  }

  listee(dalles, coords) {
    return dalles?.[coords.z]?.has(`${coords.x}/${coords.y}`) ?? false
  }

  coucheVraie() {
    this.couches.vrai ||= this.surveillerEchecs(this.decouper(creerCoucheDalles(this.L, {
      modele: this.url(this.style, "{z}/{x}/{y}.webp"), estListee: this.estListee, options: this.optionsCouche
    })))
    return this.couches.vrai
  }

  coucheBlanche() {
    this.couches.blanche ||= this.surveillerEchecs(this.decouper(creerCoucheBlanche(this.L, {
      dalle: (chemin) => this.url(this.style, `${chemin}.webp`),
      masque: (chemin) => this.url(this.tuilesValue.masque, `${chemin}.png`),
      estListee: this.estListee, masqueListe: this.masqueListe, options: this.optionsCouche
    })))
    return this.couches.blanche
  }

  // La couche d'un état { moment, saison, meteo } ; l'état neutre est le diorama d'origine.
  coucheAmbiance(etat) {
    const cle = `${etat.moment}|${etat.saison}|${etat.meteo}`
    if (cle === `${NEUTRE.moment}|${NEUTRE.saison}|${NEUTRE.meteo}`) return this.coucheVraie()
    const t = this.tuilesValue
    if (!this.couches[cle]) {
      const publies = Promise.all(PUBLIEES.map((nom) => Object.values(etat).includes(nom) ? this.etalonnage(nom) : null))
        .then((jsons) => Object.fromEntries(PUBLIEES.map((nom, i) => [nom, jsons[i]])))
      this.couches[cle] = this.surveillerEchecs(this.decouper(creerCoucheAmbiance(this.L, {
        cle,
        uniformes: publies.then((p) => uniformesEtat(etat, p, { arbres: Boolean(this.dallesArbres), projection: this.projection })),
        dalle: (chemin) => this.url(this.style, `${chemin}.webp`),
        propriete: (chemin) => this.url(t.propriete, `${chemin}.png`),
        masque: (chemin) => this.url(t.masque, `${chemin}.png`),
        arbres: (chemin) => this.url(t.arbres, `${chemin}.png`),
        estListee: this.estListee, masqueListe: this.masqueListe,
        arbresListe: (coords) => this.listee(this.dallesArbres, coords),
        moment: etat.moment,
        lampadaires: LAMPADAIRES.intensite[etat.moment] ? this.lampadaires() : null,
        options: this.optionsCouche
      })))
    }
    return this.couches[cle]
  }

  // Les lampadaires (diorama/lampadaires), lus une fois, au premier moment éclairé ; null sans eux.
  lampadaires() {
    const t = this.tuilesValue
    this.promesseLampadaires ||= t.lumieres && t.disponibles?.lumieres
      ? chargerLampadaires(`${t.base}/${t.lumieres}`, this.projection).catch((erreur) => {
        console.error(`lampadaires : ${t.base}/${t.lumieres} illisible, la nuit reste sans lumières.`, erreur)
        return null
      })
      : Promise.resolve().then(() => {
        if (this.developpementValue) console.warn("lampadaires : ni lumieres-nuit/ ni lampadaires-bdtopo/ publiés sur R2, la nuit reste sans lumières.")
        return null
      })
    return this.promesseLampadaires
  }

  // Nombre de lampadaires éclairés dont le pied est dans la vue (null tant qu'ils ne sont pas lus).
  async lampadairesDansLaVue() {
    const index = await this.lampadaires()
    if (!index || !this.carte) return null
    const b = this.carte.getPixelBounds(), k = 2 ** (8 - this.carte.getZoom())
    return compterLampadaires(index, b.min.x * k, b.min.y * k, b.max.x * k, b.max.y * k)
  }

  // L'étalonnage publié `nom` (JSON), lu une fois ; null s'il est illisible.
  etalonnage(nom) {
    this.etalonnages ||= {}
    this.etalonnages[nom] ||= lireAmbiance(`${this.tuilesValue.base}/${this.tuilesValue.ambiances[nom]}`)
      .catch((erreur) => { console.error("ambiance :", erreur); return null })
    return this.etalonnages[nom]
  }

  // Maquette blanche et ambiance sont exclusives : la blanche l'emporte tant qu'elle est cochée.
  coucheCourante() {
    return this.rendu === "blanche" ? this.coucheBlanche() : this.coucheAmbiance(this.etat)
  }

  // On ajoute avant de retirer : l'attribution ne doit pas s'effacer le temps d'une bascule.
  poserCoucheFond(nouvelle) {
    nouvelle.addTo(this.carte)
    if (this.coucheFond && this.coucheFond !== nouvelle) this.carte.removeLayer(this.coucheFond)
    this.coucheFond = nouvelle
  }

  // ─── Ambiance (moment, saison, météo) et maquette blanche, gardées sur l'appareil ─────
  valide(reglage, valeur) {
    if (!REGLAGES[reglage].includes(valeur)) return false
    return !PUBLIEES.includes(valeur) || Boolean(this.tuilesValue.disponibles?.ambiances?.includes(valeur))
  }

  lireReglages() {
    const d = this.tuilesValue.disponibles || {}
    this.rendu = d.blanche && lire(CLE_BLANCHE) === "1" ? "blanche" : "vrai"
    // Reprise de l'ancienne clé (une seule ambiance) tant qu'aucun réglage n'est gardé.
    const ancienne = lire(CLE_AMBIANCE)
    const reprise = { "heure-bleue": { moment: "heure-bleue" }, automne: { saison: "automne" }, hiver: { saison: "hiver" } }[ancienne] || {}
    const auto = lire(CLE_AUTO)
    this.auto = auto === null ? ancienne === "auto" : auto === "1"
    this.choisis = Object.fromEntries(Object.keys(REGLAGES).map((r) => {
      const valeur = lire(CLES_REGLAGES[r]) ?? reprise[r]
      return [r, this.valide(r, valeur) ? valeur : NEUTRE[r]]
    }))
    this.meteoReelle = meteoGardee() || "clair"
    this.etat = this.etatEffectif()
  }

  // Ce qu'« Automatique » retient maintenant (sans filtre de disponibilité).
  etatAuto() {
    return { moment: momentAuto(), saison: saisonAuto(), meteo: this.meteoReelle }
  }

  etatAffiche() {
    return this.auto ? this.etatAuto() : this.choisis
  }

  // L'état réellement posé : un étalonnage publié absent revient à l'origine de son réglage.
  etatEffectif() {
    const etat = this.etatAffiche()
    return Object.fromEntries(Object.keys(REGLAGES).map((r) => [r, this.valide(r, etat[r]) ? etat[r] : NEUTRE[r]]))
  }

  rafraichirAuto() {
    this.appliquerAmbiance()
    meteoAuto().then((meteo) => {
      if (meteo === this.meteoReelle) return
      this.meteoReelle = meteo
      if (this.auto) this.appliquerAmbiance()
    })
  }

  choisirAuto(event) {
    this.auto = event.target.checked
    ecrire(CLE_AUTO, this.auto ? "1" : "0")
    this.quitterBlanche()
    if (this.auto) this.rafraichirAuto()
    else this.appliquerAmbiance()
  }

  // Un choix à la main quitte le mode automatique, en gardant les deux autres réglages tels qu'affichés.
  choisirReglage(event) {
    const { reglage } = event.target.dataset
    if (this.auto) {
      this.choisis = this.etatEffectif()
      this.auto = false
      ecrire(CLE_AUTO, "0")
    }
    this.choisis = { ...this.choisis, [reglage]: event.target.value }
    Object.entries(this.choisis).forEach(([r, v]) => ecrire(CLES_REGLAGES[r], v))
    this.quitterBlanche()
    this.appliquerAmbiance()
  }

  // L'ambiance choisie l'emporte sur la maquette blanche.
  quitterBlanche() {
    if (this.rendu !== "blanche") return
    this.rendu = "vrai"
    ecrire(CLE_BLANCHE, "0")
    if (this.carte && this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
  }

  choisirBlanche(event) {
    this.rendu = event.target.checked ? "blanche" : "vrai"
    ecrire(CLE_BLANCHE, this.rendu === "blanche" ? "1" : "0")
    if (this.carte && this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
    this.majMeteo()
    this.majCalques()
  }

  appliquerAmbiance() {
    const avant = this.etat
    this.etat = this.etatEffectif()
    const change = Object.keys(REGLAGES).some((r) => avant?.[r] !== this.etat[r])
    if (change && this.carte && this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
    this.majMeteo()
    this.majCalques()
  }

  // Particules de pluie ou de neige (diorama/precipitations), et halo des pins la nuit (data-moment).
  majMeteo() {
    const ambiance = this.carte && this.fond === "diorama" && this.rendu !== "blanche"
    const type = ambiance && this.etat.meteo !== "clair" ? this.etat.meteo : null
    if (this.precipitations && (this.precipitations.type !== type || this.precipitations.carte !== this.carte)) {
      this.precipitations.detruire()
      this.precipitations = null
    }
    if (type && !this.precipitations) this.precipitations = new Precipitations(this.L, this.carte, type)
    if (ambiance) this.element.dataset.moment = this.etat.moment
    else delete this.element.dataset.moment
  }

  // ─── Les points et leurs marqueurs ───────────────────────────────────────────────────
  // Position Leaflet de chaque point sur le fond courant. Diorama : hors de la mosaïque, sur une
  // dalle vide ou hors de la Métropole, pas de marqueur. Plan : tous les points géolocalisés.
  poserPoints() {
    const L = this.L
    this.points.forEach((p) => {
      p.latlng = null
      p.marqueur = null // l'icône suit le point : on la refait sur la nouvelle carte
      if (!Number.isFinite(p.latitude) || !Number.isFinite(p.longitude)) return
      if (this.fond === "plan") { p.latlng = L.latLng(p.latitude, p.longitude); return }
      const px = this.pixelDansLeDiorama(p)
      if (px) p.latlng = this.carte.unproject(L.point(px[0], px[1]), NIVEAU_MAX)
    })
    this.poses = this.points.filter((p) => p.latlng)
    this.majCompteurs()
  }

  iconePin(p) {
    const cat = this.categorie(p.categorie)
    const pin = this.modelePinTarget.content.firstElementChild.cloneNode(true)
    pin.style.setProperty("--c", cat.couleur)
    pin.dataset.id = p.id
    pin.classList.toggle("acc-aujourdhui", dansLaFenetre(p, "aujourdhui"))
    const picto = pin.querySelector(".pin-picto")
    picto.src = cat.icone
    picto.srcset = `${cat.icone2x} 2x`
    // Compense la boîte utile du PNG (PINS.fraction_utile) : même hauteur visible pour toutes les
    // catégories, quelle que soit leur marge transparente d'origine.
    picto.style.setProperty("--icone-echelle", echelleIcone(cat.cle))
    // Respiration : phase propre à ce pin (son identifiant), pour ne pas toutes pulser ensemble.
    const { periode, retard } = respiration(p.id)
    const vol = pin.querySelector(".pin-vol")
    vol.style.animationDuration = `${periode.toFixed(2)}s`
    vol.style.animationDelay = `${retard.toFixed(2)}s`
    // Apparition décalée pin par pin, plafonnée : seulement au premier dessin de CE marqueur (mis en
    // cache par p.marqueur ||= dans dessinerPins), jamais rejouée aux zooms/filtres suivants.
    this.indexApparition = (this.indexApparition ?? -1) + 1
    const retardApparition = Math.min(this.indexApparition * PINS.apparition.decalage_ms, PINS.apparition.decalage_max_ms)
    picto.style.setProperty("--pin-retard-apparition", `${retardApparition}ms`)
    // Boîte : icône (52 bureau / 44 mobile) + tige (44) − recouvrement (4) jusqu'au pied, ancre au
    // centre du socle (dispositionPin, diorama/bouquets.js).
    const { icone, pied, hauteur } = dispositionPin(this.etroitEcran())
    return this.L.divIcon({ html: pin, className: "acc-pin", iconSize: [icone, hauteur], iconAnchor: [icone / 2, pied] })
  }

  // ─── Pins isolés et bouquets ─────────────────────────────────────────────────────────
  // Groupes des points filtrés au zoom donné (pieds à moins de SEUIL_BOUQUET_PX à l'écran).
  groupes(zoom) {
    const elements = this.poses.filter((p) => this.passe(p)).map((p) => {
      const { x, y } = this.carte.project(p.latlng, zoom)
      return { p, x, y }
    })
    return regrouper(elements).map((g) => g.map((e) => e.p))
  }

  // Redessine pins et bouquets : fin de zoom et changement de filtre. `ancres` retient, pour chaque
  // point affiché, où poser sa popup (pied + décalage jusqu'au haut de son icône).
  dessinerPins() {
    if (!this.calquePins) return
    this.calquePins.clearLayers()
    this.ancres = new Map()
    const { icone } = dispositionPin(this.etroitEcran())
    for (const groupe of this.groupes(this.carte.getZoom())) {
      if (groupe.length === 1) {
        const p = groupe[0]
        p.marqueur ||= this.L.marker(p.latlng, { icon: this.iconePin(p), title: p.titre, riseOnHover: true })
          .on("click", () => this.ouvrirPopup(p.id))
        this.calquePins.addLayer(p.marqueur)
        this.ancres.set(p.id, { latlng: p.latlng, decalage: [0, -(icone + PINS.tige_longueur_px)] })
      } else {
        this.calquePins.addLayer(this.bouquet(groupe))
      }
    }
    this.marquerSurvol()
    this.suivrePopup()
  }

  // Écarte les plus grandes catégories (échelle de compensation la plus forte, ex. « formation ») les
  // unes des autres dans l'éventail : la plus grande à une extrémité, la 2e à l'autre, la 3e au
  // centre, etc. Une tige commune (PINS.tige_longueur_px) ne peut pas garantir un éventail sans le
  // moindre recouvrement pour de très grandes icônes voisines ; les séparer autant que possible
  // limite ce risque au cas où deux catégories parmi les plus grandes se retrouveraient côte à côte.
  ecarterGrandes(fleurs) {
    const tri = [...fleurs].sort((a, b) => echelleIcone(b.categorie) - echelleIcone(a.categorie))
    const place = new Array(fleurs.length)
    let lo = 0, hi = fleurs.length - 1
    tri.forEach((p, i) => { if (i % 2 === 0) place[lo++] = p; else place[hi--] = p })
    return place
  }

  // Un pied commun (pastille blanche cerclée de violet) au barycentre du groupe, une tige par fleur
  // en éventail, 6 fleurs au plus et une pastille « +n » qui zoome sur le groupe.
  bouquet(groupe) {
    const L = this.L
    const zMax = this.carte.getMaxZoom()
    const pixels = groupe.map((p) => this.carte.project(p.latlng, zMax))
    const centre = this.carte.unproject(L.point(
      pixels.reduce((s, q) => s + q.x, 0) / pixels.length, pixels.reduce((s, q) => s + q.y, 0) / pixels.length
    ), zMax)
    const fleurs = this.ecarterGrandes(groupe.slice(0, FLEURS_MAX).sort((a, b) => a.latlng.lng - b.latlng.lng))
    const { icone: tailleIcone } = dispositionPin(this.etroitEcran())
    const el = document.createElement("div")
    el.className = "bouquet"
    eventail(fleurs.length).forEach((t, i) => {
      const p = fleurs[i], cat = this.categorie(p.categorie)
      const tige = document.createElement("span")
      tige.className = "bouquet-tige"
      tige.dataset.id = p.id
      tige.style.cssText = `height:${t.longueur}px;transform:rotate(${t.angle}deg)`
      tige.style.setProperty("--c", cat.couleur)
      // L'enveloppe porte la respiration et la lueur du jour (transform/opacity indépendants de
      // l'échelle et du rebond de la fleur, posés plus bas sur l'<img> elle-même) : voir accueil.css.
      const enveloppe = document.createElement("span")
      enveloppe.className = "bouquet-fleur-vol"
      enveloppe.dataset.id = p.id
      enveloppe.style.setProperty("--c", cat.couleur)
      enveloppe.style.left = `${t.x - tailleIcone / 2}px`
      enveloppe.style.top = `${t.y - tailleIcone + PINS.recouvrement_px}px`
      enveloppe.classList.toggle("acc-aujourdhui", dansLaFenetre(p, "aujourdhui"))
      const { periode, retard } = respiration(p.id)
      enveloppe.style.animationDuration = `${periode.toFixed(2)}s`
      enveloppe.style.animationDelay = `${retard.toFixed(2)}s`
      const fleur = document.createElement("img")
      fleur.className = "bouquet-fleur"
      fleur.dataset.id = p.id
      fleur.src = cat.icone
      fleur.srcset = `${cat.icone2x} 2x`
      fleur.alt = p.titre
      fleur.title = p.titre
      fleur.style.setProperty("--icone-echelle", echelleIcone(cat.cle))
      enveloppe.append(fleur)
      el.append(tige, enveloppe)
      this.ancres.set(p.id, { latlng: centre, decalage: [t.x, t.y - tailleIcone] })
    })
    const pied = document.createElement("span")
    pied.className = "bouquet-pied"
    el.append(pied)
    if (groupe.length > FLEURS_MAX) {
      const plus = document.createElement("span")
      plus.className = "bouquet-plus"
      plus.textContent = `+${groupe.length - FLEURS_MAX}`
      plus.title = "Zoomer sur ce groupe"
      el.append(plus)
    }
    const icone = L.divIcon({ html: el, className: "acc-bouquet", iconSize: [0, 0], iconAnchor: [0, 0] })
    return L.marker(centre, { icon: icone, title: `${groupe.length} initiatives` }).on("click", (e) => {
      const cible = e.originalEvent?.target
      if (cible?.closest?.(".bouquet-plus")) {
        const { haut, bas } = this.marges()
        this.carte.fitBounds(L.latLngBounds(groupe.map((p) => p.latlng)),
                             { paddingTopLeft: [40, haut + 90], paddingBottomRight: [40, bas + 20] })
        return
      }
      this.ouvrirPopup(cible?.closest?.("[data-id]")?.dataset.id || fleurs[0].id)
    })
  }

  // Premier zoom (depuis le zoom courant) où le point n'est plus dans un bouquet.
  zoomIsole(p) {
    for (let z = this.carte.getZoom(); z < this.carte.getMaxZoom(); z++) {
      if (this.groupes(z).find((g) => g.includes(p))?.length === 1) return z
    }
    return this.carte.getMaxZoom()
  }

  // ─── La popup d'un pin ───────────────────────────────────────────────────────────────
  // Ce que le logo (en haut), la légende et le volet (en bas) recouvrent de la carte, en px.
  marges() {
    const cadre = this.carteTarget.getBoundingClientRect()
    let haut = 12, bas = 12
    const logo = this.element.querySelector(".acc-entete")
    if (logo?.offsetParent) haut = Math.max(haut, logo.getBoundingClientRect().bottom - cadre.top + 10)
    for (const el of this.element.querySelectorAll(".acc-volet, .acc-volet .acc-categories")) {
      const r = el.getBoundingClientRect()
      // Sur bureau, le volet est à gauche de la carte : il ne la recouvre pas.
      if (r.right <= cadre.left + 1 || r.left >= cadre.right - 1 || r.top >= cadre.bottom) continue
      bas = Math.max(bas, cadre.bottom - r.top + 10)
    }
    return { haut, bas }
  }

  ouvrirPopup(id) {
    const p = this.points.find((q) => q.id === id), ancre = this.ancres?.get(id)
    if (!p || !ancre) return
    const L = this.L
    if (!this.popup) {
      this.popup = L.popup({ className: "acc-popup", minWidth: 240, maxWidth: 240, autoPan: true })
      this.popup.on("remove", () => { this.popupId = null })
    }
    const { haut, bas } = this.marges()
    Object.assign(this.popup.options, {
      offset: L.point(ancre.decalage), autoPanPaddingTopLeft: L.point(12, haut), autoPanPaddingBottomRight: L.point(12, bas)
    })
    this.selectionner(id, { depuisCarte: true })
    this.popup.setLatLng(ancre.latlng).setContent(this.contenuPopup(p)).openOn(this.carte)
    this.popupId = id
    this.animerSelection(id)
  }

  // Rebond + onde au pied (accueil.css), à l'ouverture d'une popup. Relance l'animation même si le
  // même pin est recliqué pendant qu'elle joue encore (retrait puis pose de la classe, à la frame
  // suivante : offsetWidth force le navigateur à « oublier » l'animation en cours).
  animerSelection(id) {
    const cible = this.carteTarget.querySelector(`.pin[data-id="${id}"], .bouquet-fleur[data-id="${id}"]`)
    if (!cible) return
    cible.classList.remove("acc-rebond")
    void cible.offsetWidth
    cible.classList.add("acc-rebond")
    clearTimeout(cible._finRebond)
    cible._finRebond = setTimeout(() => cible.classList.remove("acc-rebond"), PINS.selection.onde_duree_ms + 50)
  }

  // Après un nouveau regroupement, la popup suit sa fleur ; elle se ferme si le point est filtré.
  suivrePopup() {
    if (!this.popupId || !this.popup?.isOpen()) return
    const ancre = this.ancres.get(this.popupId)
    if (!ancre) { this.carte.closePopup(); return }
    this.popup.options.offset = this.L.point(ancre.decalage)
    this.popup.setLatLng(ancre.latlng)
  }

  contenuPopup(p) {
    const cat = this.categorie(p.categorie)
    const el = this.modelePopupTarget.content.firstElementChild.cloneNode(true)
    el.style.setProperty("--c", cat.couleur)
    const photo = el.querySelector(".bulle-photo"), picto = el.querySelector(".bulle-picto")
    picto.src = cat.icone2x
    if (p.photo) {
      picto.hidden = true
      // Une photo morte retombe sur l'icône de catégorie, dans la même boîte.
      photo.addEventListener("error", () => { photo.hidden = true; picto.hidden = false }, { once: true })
      photo.src = p.photo
    } else photo.hidden = true
    const etiquetteCat = el.querySelector(".bulle-cat")
    etiquetteCat.textContent = cat.libelle
    etiquetteCat.style.color = encreSur(cat.couleur)
    el.querySelector(".bulle-titre").textContent = p.titre
    this.remplir(el, ".bulle-date", periode(p) && [periode(p), p.horaire].filter(Boolean).join(" · "))
    this.remplir(el, ".bulle-commune", p.commune)
    const lien = el.querySelector(".bulle-lien")
    lien.href = p.url
    lien.querySelector("span").textContent = p.categorie === HISTOIRES ? "Lire l'histoire" : "Voir la fiche"
    return el
  }

  // Échap ferme d'abord le panneau Calques, puis la popup.
  echap(event) {
    if (event.key !== "Escape") return
    if (this.hasPanneauCalquesTarget && !this.panneauCalquesTarget.hidden) this.fermerCalques()
    else this.fermerPopup()
  }

  fermerPopup() {
    if (this.popup?.isOpen()) this.carte.closePopup()
  }

  categorie(cle) {
    return this.categoriesParCle[cle] || { cle, libelle: "Autre", couleur: "#6b6880", icone: "", icone2x: "" }
  }

  // ─── Les filtres ─────────────────────────────────────────────────────────────────────
  passe(p) {
    const f = this.filtre
    if (f.categories.size && !f.categories.has(p.categorie)) return false
    if (f.favoris && !this.favoris.has(p.id)) return false
    return true
  }

  appliquerFiltres() {
    this.dessinerPins()
    this.majVolet()
  }

  basculerCategorie({ params: { cle } }) {
    const c = this.filtre.categories
    c.has(cle) ? c.delete(cle) : c.add(cle)
    this.categorieTargets.forEach((b) => b.setAttribute("aria-pressed", String(c.has(b.dataset.cle))))
    this.appliquerFiltres()
  }

  majCompteurs() {
    const liste = this.poses || this.points
    const comptes = {}
    liste.forEach((p) => { comptes[p.categorie] = (comptes[p.categorie] || 0) + 1 })
    this.categorieTargets.forEach((b) => {
      const n = comptes[b.dataset.cle] || 0
      b.querySelector("[data-compte]").textContent = n
      b.classList.toggle("acc-cat--vide", n === 0)
    })
  }

  // ─── Favoris (sur l'appareil seulement) ──────────────────────────────────────────────
  lireFavoris() {
    try { return new Set(JSON.parse(localStorage.getItem(CLE_FAVORIS) || "[]")) } catch { return new Set() }
  }

  ecrireFavoris() {
    try { localStorage.setItem(CLE_FAVORIS, JSON.stringify([...this.favoris])) } catch { /* stockage indisponible */ }
  }

  basculerFavoris() {
    this.filtre.favoris = !this.filtre.favoris
    this.majOnglets()
    this.appliquerFiltres()
    if (this.filtre.favoris) this.dispatch("ouvrir-volet") // la bottom sheet montre les favoris
  }

  // Toucher « Carte » quand les favoris sont affichés revient à la carte complète.
  voirCarte() {
    if (!this.filtre.favoris) return
    this.filtre.favoris = false
    this.majOnglets()
    this.appliquerFiltres()
  }

  // L'onglet courant : Carte, sauf pendant que le filtre Favoris est actif.
  majOnglets() {
    const favoris = this.filtre.favoris
    if (this.hasOngletFavorisTarget) this.ongletFavorisTarget.setAttribute("aria-pressed", String(favoris))
    if (this.hasOngletCarteTarget) {
      if (favoris) this.ongletCarteTarget.removeAttribute("aria-current")
      else this.ongletCarteTarget.setAttribute("aria-current", "page")
    }
  }

  // ─── Le volet (majVolet de la v3) ────────────────────────────────────────────────────
  // « Au centre de la vue » : tri par distance à l'écran au centre de la carte ; aucun nombre de
  // mètres n'est affiché. Les dates à venir passent devant, sous leur
  // étiquette ; s'il n'y en a aucune, le volet devient « Toujours d'actualité » et ne liste
  // que les fiches sans date. Une fiche passée quitte le volet.
  majVolet() {
    const jour = aujourdhui()
    const visibles = (this.poses || this.points).filter((p) => this.passe(p) && !estPasse(p, jour))
    const cle = this.carte ? (p) => this.distanceEcran(p) : () => 0
    visibles.forEach((p) => { p.tri = cle(p) })
    const parDistance = (a, b) => a.tri - b.tri
    const aVenir = visibles.filter((p) => estAVenir(p, jour))
      .sort((a, b) => Math.max(a.debut, jour) - Math.max(b.debut, jour) || parDistance(a, b))
    const sansDate = visibles.filter((p) => !p.debut && !p.fin).sort(parDistance)

    let titre = "Au centre de la vue"
    if (!aVenir.length) titre = "Toujours d'actualité"
    const titreVolet = this.filtre.favoris ? "Vos favoris" : titre
    this.voletTitreTarget.textContent = titreVolet
    this.poigneeTitreTarget.textContent = titreVolet

    let liste = [...aVenir, ...sansDate]
    if (this.selection) {
      const choisi = liste.find((p) => p.id === this.selection)
      if (choisi) liste = [choisi, ...liste.filter((p) => p !== choisi)]
    }
    this.fichesTarget.replaceChildren(...liste.slice(0, FICHES_MAX).map((p) => this.fiche(p)))
    this.videTarget.hidden = liste.length > 0
    this.videTarget.textContent = this.filtre.favoris
      ? "Aucun favori pour l'instant : touchez le signet d'une fiche pour la garder ici."
      : "Aucune initiative ne correspond à ces filtres."
    if (this.developpementValue && this.hasStatsTarget) this.statsTarget.innerHTML = this.statistiques(liste.length, jour)
    this.majCompteur()
  }

  // Nombre de lieux (filtres compris) dans le cadrage actuel de la carte ; sans carte, le total filtré.
  majCompteur() {
    const bornes = this.carte?.getBounds()
    const n = (this.poses || this.points).filter((p) => this.passe(p) && (!bornes || (p.latlng && bornes.contains(p.latlng)))).length
    this.compteurTarget.textContent = `${n} ${n > 1 ? "lieux" : "lieu"}`
  }

  fiche(p) {
    const cat = this.categorie(p.categorie)
    const el = this.modeleFicheTarget.content.firstElementChild.cloneNode(true)
    el.dataset.id = p.id
    el.style.setProperty("--c", cat.couleur)
    el.classList.toggle("fiche--active", p.id === this.selection)
    const photo = el.querySelector(".fiche-photo")
    const pictoSeul = el.querySelector(".fiche-picto-seul")
    pictoSeul.src = cat.icone2x
    if (p.photo) {
      pictoSeul.hidden = true
      // Une photo morte (URL externe disparue) retombe sur le pictogramme, dans la même boîte.
      photo.addEventListener("error", () => { photo.hidden = true; pictoSeul.hidden = false }, { once: true })
      photo.src = p.photo
    } else photo.hidden = true
    const date = el.querySelector(".fiche-date")
    const texteDate = etiquette(p)
    if (texteDate) { date.textContent = texteDate; date.style.color = encreSur(cat.couleur) } else date.remove()
    const icone = el.querySelector(".fiche-cat")
    icone.src = cat.icone
    icone.srcset = `${cat.icone2x} 2x`
    icone.alt = cat.libelle
    const lien = el.querySelector(".fiche-lien")
    lien.href = p.url
    lien.textContent = p.titre
    this.remplir(el, ".fiche-commune", p.commune)
    this.remplir(el, ".fiche-quand", [periode(p), p.horaire].filter(Boolean).join(" · "))
    const signet = el.querySelector(".fiche-signet")
    const favori = this.favoris.has(p.id)
    signet.setAttribute("aria-pressed", String(favori))
    signet.setAttribute("aria-label", favori ? `Retirer « ${p.titre} » des favoris` : `Garder « ${p.titre} » en favori`)
    return el
  }

  remplir(fiche, selecteur, texte) {
    const ligne = fiche.querySelector(selecteur)
    if (texte) ligne.querySelector("span").textContent = texte
    else ligne.remove()
  }

  // Le texte de contrôle de la v3, sous le volet, en développement seulement.
  statistiques(n, jour) {
    const total = (this.poses || this.points).length
    const dates = this.points.filter((p) => p.debut)
    const aVenir = dates.filter((p) => estAVenir(p, jour))
    const mots = [`<b>${n}</b> sur ${total} posées.`]
    if (!dates.length) {
      mots.push("<b>Aucune n'est datée</b> — la base ne porte ni début ni fin : Aucune date à venir à montrer.")
    } else if (!aVenir.length) {
      const derniere = new Date(Math.max(...dates.map((p) => (p.fin || p.debut).getTime())))
      mots.push(`<b>${dates.length}</b> sur ${this.points.length} portent une date, et <b>toutes sont passées</b> — ` +
                `la plus récente est du ${jourCourt(derniere).replace(/\.$/, "")}. « Aujourd'hui » et « Cette semaine » ` +
                "rendent donc <b>0</b> : le filtre lit bien les dates, c'est l'agenda qui est vide.")
    } else {
      mots.push(`<b>${dates.length}</b> sur ${this.points.length} portent une date, dont <b>${aVenir.length}</b> à venir.`)
    }
    mots.push(`<b>${this.points.filter((p) => p.photo).length}</b> portent une photo.`)
    mots.push("Tri par distance au centre de la vue.")
    return mots.join(" ")
  }

  distanceEcran(p) {
    if (!p.latlng) return Infinity
    const e = this.carte.latLngToContainerPoint(p.latlng)
    const o = this.carte.latLngToContainerPoint(this.carte.getCenter())
    return Math.hypot(e.x - o.x, e.y - o.y)
  }

  // ─── Fiche ↔ marqueur ────────────────────────────────────────────────────────────────
  clicFiches(event) {
    const signet = event.target.closest(".fiche-signet")
    if (signet) {
      const id = signet.closest(".fiche").dataset.id
      this.favoris.has(id) ? this.favoris.delete(id) : this.favoris.add(id)
      this.ecrireFavoris()
      this.majVolet()
      return
    }
    const fiche = event.target.closest(".fiche")
    if (!fiche || event.target.closest("a")) return
    const p = this.points.find((q) => q.id === fiche.dataset.id)
    if (p?.latlng && this.carte) {
      this.selectionner(p.id)
      this.carte.setView(p.latlng, this.zoomIsole(p))
    }
  }

  survolFiche(event) {
    this.survol = event.target.closest(".fiche")?.dataset.id || null
    this.marquerSurvol()
  }

  finSurvol() {
    this.survol = null
    this.marquerSurvol()
  }

  // Met en avant le pin de la fiche survolée ou sélectionnée, ou sa fleur dans un bouquet.
  marquerSurvol() {
    if (!this.calquePins) return
    this.carteTarget.querySelectorAll(".acc-survole").forEach((el) => el.classList.remove("acc-survole"))
    for (const id of [this.survol, this.selection]) {
      const el = id && this.carteTarget.querySelector(`.pin[data-id="${id}"], .bouquet-fleur[data-id="${id}"]`)
      if (!el) continue
      el.classList.add("acc-survole")
      el.closest(".leaflet-marker-icon")?.classList.add("acc-survole")
    }
  }

  selectionner(id, { depuisCarte = false } = {}) {
    this.selection = id
    this.majVolet()
    this.marquerSurvol()
    if (!id || !depuisCarte) return
    const fiche = this.fichesTarget.querySelector(`[data-id="${id}"]`)
    if (!fiche) return
    // On fait défiler la liste elle-même : scrollIntoView remonterait jusqu'à la page.
    const liste = this.fichesTarget, f = fiche.getBoundingClientRect(), l = liste.getBoundingClientRect()
    liste.scrollTo({ left: liste.scrollLeft + f.left - l.left - 16, top: liste.scrollTop + f.top - l.top - 8, behavior: "smooth" })
  }

  // ─── Commandes de carte ──────────────────────────────────────────────────────────────
  cadrer() {
    const pts = this.poses.filter((p) => this.passe(p)).map((p) => p.latlng)
    // Le logo, la légende et le volet recouvrent la carte : on cadre dans ce qui reste visible.
    const { haut, bas } = this.marges()
    const maxZoom = this.fond === "diorama" ? 6 : 16
    const options = { paddingTopLeft: [30, haut + 80], paddingBottomRight: [80, bas + 10], maxZoom }
    if (pts.length) this.carte.fitBounds(this.L.latLngBounds(pts), options)
    else if (this.fond === "diorama") this.carte.fitBounds(this.bornesContour())
    else this.vueInitiale()
  }

  // Centre la carte sur CENTRE_INITIAL au zoom ZOOM_INITIAL (diorama) ou ZOOM_PLAN_INITIAL (plan).
  vueInitiale() {
    if (this.fond === "plan") {
      this.carte.setView([CENTRE_INITIAL.lat, CENTRE_INITIAL.lon], ZOOM_PLAN_INITIAL, { animate: false })
      return
    }
    const [px, py] = this.projection.pixel(CENTRE_INITIAL.lat, CENTRE_INITIAL.lon)
    this.carte.setView(this.carte.unproject(this.L.point(px, py), NIVEAU_MAX), ZOOM_INITIAL, { animate: false })
  }

  // Réglage de la vue : ?debug_vue=1 affiche le centre (lat/lon), le zoom et le fond courants. Sans ce
  // paramètre, rien. Rebranché à chaque carte (bascule de fond), sur le même encart.
  brancherDebugVue() {
    if (new URLSearchParams(window.location.search).get("debug_vue") !== "1") return
    if (!this.encartDebug) {
      this.encartDebug = document.createElement("output")
      this.encartDebug.className = "acc-debug-vue"
      this.carteTarget.parentElement.appendChild(this.encartDebug)
    }
    const maj = () => {
      const { lat, lon } = this.vueGeo()
      this.encartDebug.textContent = `${this.fond} · centre ${lat.toFixed(5)}, ${lon.toFixed(5)} · zoom ${this.carte.getZoom()}`
    }
    this.carte.on("move zoom", maj)
    this.carte.whenReady(maj)
  }

  zoomer({ params: { sens } }) {
    this.carte?.setZoom(this.carte.getZoom() + Number(sens))
  }

  voirTout(event) {
    event.preventDefault()
    this.selectionner(null)
    if (this.carte) this.cadrer()
    this.dispatch("voir-tout") // la bottom sheet se replie
    this.element.querySelector("#carte")?.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  alerter(texte) {
    this.alerteTarget.textContent = texte
    this.alerteTarget.hidden = false
    clearTimeout(this.minuterieAlerte)
    this.minuterieAlerte = setTimeout(() => { this.alerteTarget.hidden = true }, 6000)
  }
}
