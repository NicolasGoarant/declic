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
import { creerCoucheAmbiance, lireAmbiance } from "diorama/ambiance"
import { resoudreAuto } from "diorama/soleil"
import { regrouper, eventail, FLEURS_MAX } from "diorama/bouquets"
import { chargerContour, creerDecoupe, poserSocle } from "diorama/contour"
import { CLE_FOND, CLE_AMBIANCE, CLE_BLANCHE, lire, ecrire, fondDeDepart } from "diorama/preferences"
import { lireDate, aujourdhui, estPasse, estAVenir, etiquette, periode, jourCourt } from "diorama/dates"

const NIVEAU_MAX = 8
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
const AMBIANCES = { origine: "origine", "heure-bleue": "heure bleue", automne: "automne", hiver: "hiver" }
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
    "boutonCalques", "panneauCalques", "voileCalques", "choixFond", "rubriqueAmbiance", "choixAmbiance",
    "choixBlanche", "ambianceAuto"
  ]

  connect() {
    this.categoriesParCle = Object.fromEntries(this.categoriesValue.map((c) => [c.cle, c]))
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
    this.observateur?.disconnect()
    window.removeEventListener("orientationchange", this.surOrientation)
    this.carte?.remove()
    this.carte = null
  }

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

  async chargerManifeste() {
    const t = this.tuilesValue
    const reponse = await fetch(`${t.base}/${t.lot}/manifeste.json`)
    if (!reponse.ok) throw new Error(`manifeste HTTP ${reponse.status}`)
    this.manifeste = await reponse.json()
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

  // Le pin (40 × 88, ancré au pied) : on descend la vue pour que le pictogramme soit au centre.
  poserPinMini(p, latlng, zoom) {
    this.L.marker(latlng, { icon: this.iconePin(p), title: p.titre, interactive: false, keyboard: false }).addTo(this.carte)
    this.carte.setView(latlng, zoom, { animate: false })
    this.carte.panBy([0, -40], { animate: false })
  }

  // ─── Démarrage : bibliothèques, manifeste, projection, carte ─────────────────────────
  // Sans diorama (non publié, ou manifeste illisible), la carte démarre sur le plan.
  async demarrer() {
    const t = this.tuilesValue
    this.dioramaDispo = Boolean(t.disponibles?.vrai)
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
        await this.chargerManifeste()
        this.preparerDecoupe(await contour)
      } catch (erreur) {
        console.error("diorama :", erreur)
        this.dioramaDispo = false
        this.alerter("Le diorama n'a pas pu se charger : voici le plan.")
      }
    }
    if (!this.carteTarget.isConnected) return
    this.fond = this.dioramaDispo ? fondDeDepart() : "plan"
    this.lireAmbianceMemorisee()
    this.construireCarte()
    this.vueInitiale()
    this.majCalques()
    if (this.dioramaDispo && t.disponibles.blanche) this.chargerMasque()
    if (this.dioramaDispo && t.disponibles.ambiances?.length) {
      this.minuterieAuto = setInterval(() => { if (this.ambianceChoisie === "auto") this.appliquerAmbiance("auto") }, 60000)
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
    this.brancherDebugVue()
    this.poserPoints()
    this.appliquerFiltres()
    this.suivreTaille()
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

  // Au dézoom maximal, la Métropole entière tient dans la partie visible de la carte (hors logo et volet).
  majZoomMin() {
    if (!this.carte || this.fond !== "diorama") return
    const { haut, bas } = this.marges()
    const zoom = this.carte.getBoundsZoom(this.bornesContour(), false, this.L.point(2 * 16, haut + bas))
    this.carte.setMinZoom(Math.max(0, Math.min(zoom, NIVEAU_MAX - 1)))
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
    this.choixAmbianceTargets.forEach((c) => { c.checked = c.value === this.ambianceChoisie })
    if (this.hasChoixBlancheTarget) this.choixBlancheTarget.checked = this.rendu === "blanche"
    // Ce que « Automatique » donnerait maintenant, qu'il soit coché ou non.
    if (this.hasAmbianceAutoTarget) this.ambianceAutoTarget.textContent = ` : ${AMBIANCES[this.resoudre("auto")]}`
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

  async chargerMasque() {
    try {
      const reponse = await fetch(this.url(this.tuilesValue.masque, "manifeste.json"))
      if (reponse.ok) {
        const manifeste = await reponse.json()
        if (manifeste.dalles) this.dallesMasque = this.indexerDalles(manifeste)
      }
    } catch (erreur) {
      console.warn("diorama : manifeste du masque illisible", erreur)
    }
  }

  coucheVraie() {
    this.couches.vrai ||= this.decouper(creerCoucheDalles(this.L, {
      modele: this.url(this.tuilesValue.lot, "{z}/{x}/{y}.webp"), estListee: this.estListee, options: this.optionsCouche
    }))
    return this.couches.vrai
  }

  coucheBlanche() {
    this.couches.blanche ||= this.decouper(creerCoucheBlanche(this.L, {
      dalle: (chemin) => this.url(this.tuilesValue.lot, `${chemin}.webp`),
      masque: (chemin) => this.url(this.tuilesValue.masque, `${chemin}.png`),
      estListee: this.estListee, masqueListe: this.masqueListe, options: this.optionsCouche
    }))
    return this.couches.blanche
  }

  coucheAmbiance(nom) {
    if (nom === "origine") return this.coucheVraie()
    const t = this.tuilesValue
    if (!this.couches[nom]) {
      const parametres = lireAmbiance(`${t.base}/${t.ambiances[nom]}`)
      parametres.catch((erreur) => console.error("ambiance :", erreur))
      this.couches[nom] = this.decouper(creerCoucheAmbiance(this.L, {
        dalle: (chemin) => this.url(t.lot, `${chemin}.webp`),
        propriete: (chemin) => this.url(t.propriete, `dalles/${chemin}.png`),
        masque: (chemin) => this.url(t.masque, `${chemin}.png`),
        estListee: this.estListee, masqueListe: this.masqueListe,
        parametres: parametres.catch(() => null), options: this.optionsCouche
      }))
    }
    return this.couches[nom]
  }

  // Maquette blanche et ambiance sont exclusives : la blanche l'emporte tant qu'elle est cochée.
  coucheCourante() {
    return this.rendu === "blanche" ? this.coucheBlanche() : this.coucheAmbiance(this.ambianceEffective)
  }

  // On ajoute avant de retirer : l'attribution ne doit pas s'effacer le temps d'une bascule.
  poserCoucheFond(nouvelle) {
    nouvelle.addTo(this.carte)
    if (this.coucheFond && this.coucheFond !== nouvelle) this.carte.removeLayer(this.coucheFond)
    this.coucheFond = nouvelle
  }

  // ─── Ambiance et maquette blanche (diorama seulement), gardées sur l'appareil ─────────
  lireAmbianceMemorisee() {
    const d = this.tuilesValue.disponibles || {}
    const nom = lire(CLE_AMBIANCE)
    const valide = nom === "origine" || (d.ambiances?.length && (nom === "auto" || d.ambiances.includes(nom)))
    this.rendu = d.blanche && lire(CLE_BLANCHE) === "1" ? "blanche" : "vrai"
    this.ambianceChoisie = valide ? nom : "origine"
    this.ambianceEffective = this.resoudre(this.ambianceChoisie)
  }

  // L'ambiance réellement posée : « auto » résolu (diorama/soleil), repli sur l'origine si absente.
  resoudre(nom) {
    const effective = nom === "auto" ? resoudreAuto() : nom
    return effective === "origine" || this.tuilesValue.disponibles?.ambiances?.includes(effective) ? effective : "origine"
  }

  choisirAmbiance(event) {
    ecrire(CLE_AMBIANCE, event.target.value)
    if (this.rendu === "blanche") { this.rendu = "vrai"; ecrire(CLE_BLANCHE, "0") } // l'ambiance choisie l'emporte
    this.appliquerAmbiance(event.target.value, { forcer: true })
  }

  choisirBlanche(event) {
    this.rendu = event.target.checked ? "blanche" : "vrai"
    ecrire(CLE_BLANCHE, this.rendu === "blanche" ? "1" : "0")
    if (this.carte && this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
    this.majCalques()
  }

  appliquerAmbiance(nom, { forcer = false } = {}) {
    const effective = this.resoudre(nom)
    const change = forcer || effective !== this.ambianceEffective
    this.ambianceChoisie = nom
    this.ambianceEffective = effective
    if (change && this.carte && this.fond === "diorama") this.poserCoucheFond(this.coucheCourante())
    this.majCalques()
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
    const picto = pin.querySelector(".pin-picto")
    picto.src = cat.icone
    picto.srcset = `${cat.icone2x} 2x`
    pin.dataset.id = p.id
    // Boîte : pictogramme 40, tige 40, socle aplati (cos 50°) ; l'ancre est le centre du socle.
    return this.L.divIcon({ html: pin, className: "acc-pin", iconSize: [40, 88], iconAnchor: [20, 80] })
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
    for (const groupe of this.groupes(this.carte.getZoom())) {
      if (groupe.length === 1) {
        const p = groupe[0]
        p.marqueur ||= this.L.marker(p.latlng, { icon: this.iconePin(p), title: p.titre, riseOnHover: true })
          .on("click", () => this.ouvrirPopup(p.id))
        this.calquePins.addLayer(p.marqueur)
        this.ancres.set(p.id, { latlng: p.latlng, decalage: [0, -84] })
      } else {
        this.calquePins.addLayer(this.bouquet(groupe))
      }
    }
    this.marquerSurvol()
    this.suivrePopup()
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
    const fleurs = groupe.slice(0, FLEURS_MAX).sort((a, b) => a.latlng.lng - b.latlng.lng) // d'ouest en est
    const el = document.createElement("div")
    el.className = "bouquet"
    eventail(fleurs.length).forEach((t, i) => {
      const p = fleurs[i], cat = this.categorie(p.categorie)
      const tige = document.createElement("span")
      tige.className = "bouquet-tige"
      tige.dataset.id = p.id
      tige.style.cssText = `height:${t.longueur}px;transform:rotate(${t.angle}deg)`
      tige.style.setProperty("--c", cat.couleur)
      const fleur = document.createElement("img")
      fleur.className = "bouquet-fleur"
      fleur.dataset.id = p.id
      fleur.src = cat.icone
      fleur.srcset = `${cat.icone2x} 2x`
      fleur.alt = p.titre
      fleur.title = p.titre
      fleur.style.cssText = `left:${t.x - 20}px;top:${t.y - 36}px`
      el.append(tige, fleur)
      this.ancres.set(p.id, { latlng: centre, decalage: [t.x, t.y - 40] })
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
