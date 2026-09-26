// La page d'accueil sur le diorama (/labo/accueil), portée de maquette-declic-v3 (nancy-3d).
//
// Leaflet et Leaflet.markercluster sont importés À LA DEMANDE, dans connect() : ce contrôleur
// est chargé d'office sur toutes les pages (eagerLoadControllersFrom), et les autres pages
// n'ont pas à tirer le CDN. Leaflet d'abord : le module de markercluster s'accroche au `L`
// global que Leaflet pose lui-même (comportement de la bibliothèque, pas de ce code).
import { Controller } from "@hotwired/stimulus"
import { creerProjection } from "diorama_projection"
import { creerCoucheDalles, creerCoucheBlanche } from "diorama/couches"
import { creerCoucheAmbiance, lireAmbiance } from "diorama/ambiance"
import { resoudreAuto } from "diorama/soleil"
import { lireDate, aujourdhui, estPasse, estAVenir, etiquette, periode, jourCourt } from "diorama/dates"

const NIVEAU_MAX = 8
// Vue initiale, à retoucher ici : place Stanislas (WGS84) et niveau de zoom Leaflet (0-8, 8 = pleine
// résolution). Ajouter ?debug_vue=1 à l'URL affiche en direct le centre et le zoom courants.
const CENTRE_INITIAL = { lat: 48.6936, lon: 6.1833 }
const ZOOM_INITIAL = 6
const ATTRIBUTION = "IGN BD TOPO®, BD ORTHO® et LiDAR HD (LO 2.0) · Métropole du Grand Nancy, Géonancy · " +
                    "© les contributeurs OpenStreetMap (ODbL)"
// Seuil de regroupement mesuré dans la v3 (m02-chevauchement.py) : deux marqueurs plus
// proches se chevauchent.
const SEUIL_GROUPE_PX = 42
const FICHES_MAX = 24
const CLE_FAVORIS = "declic:favoris"
const ETROIT = "(max-width: 699.98px)"
const BUREAU = "(min-width: 1024px)"

const normaliser = (s) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()

// Texte noir ou blanc selon la clarté de la couleur de catégorie (luminance relative WCAG).
function encreSur(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? "#1d1a2b" : "#ffffff"
}

export default class extends Controller {
  static values = { points: Array, categories: Array, tuiles: Object, developpement: Boolean }
  static targets = [
    "carte", "rendu", "ambiance", "alerte", "voletTitre", "poigneeTitre", "compteur", "fiches", "vide", "stats",
    "modeleFiche", "modelePin", "recherche", "categorie", "ongletFavoris", "ongletCarte"
  ]

  connect() {
    this.categoriesParCle = Object.fromEntries(this.categoriesValue.map((c) => [c.cle, c]))
    this.filtre = { categories: new Set(), texte: "", favoris: false }
    this.favoris = this.lireFavoris()
    this.selection = null
    this.points = this.pointsValue.map((p) => ({
      ...p, debut: lireDate(p.debut), fin: lireDate(p.fin), recherche: normaliser(`${p.titre} ${p.commune}`)
    }))
    this.categorieTargets.forEach((b) => b.style.setProperty("--c", this.categoriesParCle[b.dataset.cle]?.couleur))
    this.majCompteurs()
    this.majVolet()
    this.demarrer()
  }

  disconnect() {
    clearInterval(this.minuterieAuto)
    this.observateur?.disconnect()
    window.removeEventListener("orientationchange", this.surOrientation)
    this.carte?.remove()
    this.carte = null
  }

  // ─── Démarrage : bibliothèques, manifeste, projection, carte ─────────────────────────
  async demarrer() {
    const t = this.tuilesValue
    if (!t.disponibles?.vrai) return
    try {
      const module = await import("leaflet")
      this.L = module.default ?? module
      await import("leaflet.markercluster")
      const reponse = await fetch(`${t.base}/${t.lot}/manifeste.json`)
      if (!reponse.ok) throw new Error(`manifeste HTTP ${reponse.status}`)
      this.manifeste = await reponse.json()
    } catch (erreur) {
      console.error("diorama :", erreur)
      this.alerter("Le diorama n'a pas pu se charger. Les initiatives restent listées ci-dessous.")
      return
    }
    if (!this.carteTarget.isConnected) return
    this.projection = creerProjection(this.manifeste)
    this.dallesListees = this.indexerDalles(this.manifeste)
    this.construireCarte()
    this.poserPoints()
    this.appliquerFiltres()
    this.vueInitiale()
    this.afficherDebugVue()
    if (t.disponibles.blanche) this.chargerMasque()
    if (t.disponibles.ambiances?.length) {
      this.minuterieAuto = setInterval(() => { if (this.ambianceChoisie === "auto") this.choisirAmbianceNommee("auto") }, 60000)
    }
  }

  indexerDalles(manifeste) {
    return Object.fromEntries(Object.entries(manifeste.dalles || {})
      .map(([z, liste]) => [z, new Set(liste.map(([x, y]) => `${x}/${y}`))]))
  }

  construireCarte() {
    const L = this.L
    const [largeur, hauteur] = this.manifeste.taille_mosaique_px
    const plafond = () => (window.matchMedia(ETROIT).matches ? NIVEAU_MAX : NIVEAU_MAX + 1)
    this.carte = L.map(this.carteTarget, {
      crs: L.CRS.Simple, minZoom: 0, maxZoom: plafond(), zoomSnap: 1,
      zoomControl: false, attributionControl: false
    })
    this.bornes = L.latLngBounds(this.carte.unproject([0, hauteur], NIVEAU_MAX), this.carte.unproject([largeur, 0], NIVEAU_MAX))
    this.carte.setMaxBounds(this.bornes.pad(0.6))
    this.carte.fitBounds(this.bornes) // une vue d'abord : les grappes en ont besoin pour s'ajouter
    this.optionsCouche = {
      minZoom: 0, maxZoom: NIVEAU_MAX + 1, maxNativeZoom: NIVEAU_MAX, tileSize: 256,
      noWrap: true, bounds: this.bornes, attribution: ATTRIBUTION
    }
    this.poserAttribution()

    this.couches = {}
    this.rendu = "vrai"
    this.ambianceChoisie = "origine"
    this.ambianceEffective = "origine"
    this.poserFond(this.coucheVraie())

    this.grappes = L.markerClusterGroup({
      maxClusterRadius: SEUIL_GROUPE_PX, showCoverageOnHover: false, spiderfyOnMaxZoom: true,
      iconCreateFunction: (grappe) => L.divIcon({
        html: `<span>${grappe.getChildCount()}</span>`, className: "acc-grappe", iconSize: [44, 44]
      })
    }).addTo(this.carte)
    this.grappes.on("animationend spiderfied unspiderfied", () => this.marquerSurvol())

    this.carte.on("moveend", () => this.majVolet())
    this.carte.on("click", () => {
      this.selectionner(null)
      this.dispatch("carte-cliquee") // la bottom sheet se replie
    })
    this.suivreTaille()
  }

  // La carte occupe tout l'écran (100dvh moins la tab bar) : sa taille change avec la barre d'URL
  // mobile, la rotation ou le redimensionnement, et Leaflet doit recalculer sa surface à chaque fois.
  suivreTaille() {
    const recalculer = () => this.carte?.invalidateSize()
    this.observateur = new ResizeObserver(recalculer)
    this.observateur.observe(this.carteTarget)
    this.surOrientation = () => setTimeout(recalculer, 200) // les dimensions se stabilisent après l'événement
    window.addEventListener("orientationchange", this.surOrientation)
    requestAnimationFrame(recalculer)
  }

  // L'attribution est obligatoire (licences IGN, Géonancy, OSM) : repliée en « ⓘ », elle
  // se déplie au toucher.
  poserAttribution() {
    const controle = this.L.control.attribution({ prefix: false, position: "bottomleft" }).addTo(this.carte)
    const el = controle.getContainer()
    el.classList.add("acc-attribution")
    el.tabIndex = 0
    el.setAttribute("role", "button")
    el.setAttribute("aria-label", "Sources et licences du diorama")
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

  // ─── Les couches de fond ─────────────────────────────────────────────────────────────
  url(dossier, chemin) { return `${this.tuilesValue.base}/${dossier}/${chemin}` }

  estListee = (coords) => this.dallesListees[coords.z]?.has(`${coords.x}/${coords.y}`) ?? false

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
    this.couches.vrai ||= creerCoucheDalles(this.L, {
      modele: this.url(this.tuilesValue.lot, "{z}/{x}/{y}.webp"), estListee: this.estListee, options: this.optionsCouche
    })
    return this.couches.vrai
  }

  coucheBlanche() {
    this.couches.blanche ||= creerCoucheBlanche(this.L, {
      dalle: (chemin) => this.url(this.tuilesValue.lot, `${chemin}.webp`),
      masque: (chemin) => this.url(this.tuilesValue.masque, `${chemin}.png`),
      estListee: this.estListee, masqueListe: this.masqueListe, options: this.optionsCouche
    })
    return this.couches.blanche
  }

  coucheAmbiance(nom) {
    if (nom === "origine") return this.coucheVraie()
    const t = this.tuilesValue
    if (!this.couches[nom]) {
      const parametres = lireAmbiance(`${t.base}/${t.ambiances[nom]}`)
      parametres.catch((erreur) => console.error("ambiance :", erreur))
      this.couches[nom] = creerCoucheAmbiance(this.L, {
        dalle: (chemin) => this.url(t.lot, `${chemin}.webp`),
        propriete: (chemin) => this.url(t.propriete, `dalles/${chemin}.png`),
        masque: (chemin) => this.url(t.masque, `${chemin}.png`),
        estListee: this.estListee, masqueListe: this.masqueListe,
        parametres: parametres.catch(() => null), options: this.optionsCouche
      })
    }
    return this.couches[nom]
  }

  // On ajoute avant de retirer : l'attribution ne doit pas s'effacer le temps d'une bascule.
  poserFond(nouvelle) {
    nouvelle.addTo(this.carte)
    if (this.fond && this.fond !== nouvelle) this.carte.removeLayer(this.fond)
    this.fond = nouvelle
  }

  choisirRendu({ params: { rendu } }) {
    if (!this.carte) return
    this.appliquerRendu(rendu)
  }

  appliquerRendu(rendu) {
    this.rendu = rendu
    this.poserFond(rendu === "blanche" ? this.coucheBlanche() : this.coucheAmbiance(this.ambianceEffective))
    this.renduTargets.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.dioramaRenduParam === rendu)))
  }

  choisirAmbiance(event) {
    if (!this.carte) return
    this.choisirAmbianceNommee(event.target.value)
    // Ambiance et maquette blanche sont exclusives : l'ambiance choisie l'emporte.
    if (this.rendu === "blanche") this.appliquerRendu("vrai")
  }

  choisirAmbianceNommee(nom) {
    const disponibles = this.tuilesValue.disponibles.ambiances
    let effective = nom === "auto" ? resoudreAuto() : nom
    if (effective !== "origine" && !disponibles.includes(effective)) effective = "origine"
    this.ambianceChoisie = nom
    const change = effective !== this.ambianceEffective
    this.ambianceEffective = effective
    if (this.hasAmbianceTarget) {
      const auto = this.ambianceTarget.querySelector('option[value="auto"]')
      const libelle = this.ambianceTarget.querySelector(`option[value="${effective}"]`)?.textContent || "Origine"
      if (auto) auto.textContent = nom === "auto" ? `Auto (${libelle.toLowerCase()})` : "Auto"
    }
    if (change && this.rendu !== "blanche") this.appliquerRendu("vrai")
  }

  // ─── Les points et leurs marqueurs ───────────────────────────────────────────────────
  poserPoints() {
    const L = this.L
    const niveau8 = this.dallesListees[NIVEAU_MAX]
    this.points.forEach((p) => {
      if (!Number.isFinite(p.latitude) || !Number.isFinite(p.longitude)) return
      const [x, y] = this.projection.versL93(p.longitude, p.latitude)
      const px = this.projection.pixelL93(x, y)
      // Hors de la mosaïque, ou sur une dalle vide (hors de la couverture) : pas de marqueur.
      if (!this.projection.dansLaMosaique(px) || !niveau8?.has(`${Math.floor(px[0] / 256)}/${Math.floor(px[1] / 256)}`)) return
      p.l93 = [x, y]
      p.latlng = this.carte.unproject(L.point(px[0], px[1]), NIVEAU_MAX)
      p.marqueur = L.marker(p.latlng, { icon: this.iconePin(p), title: p.titre, riseOnHover: true })
      p.marqueur.on("click", () => this.selectionner(p.id, { depuisCarte: true }))
    })
    this.poses = this.points.filter((p) => p.marqueur)
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

  categorie(cle) {
    return this.categoriesParCle[cle] || { cle, libelle: "Autre", couleur: "#6b6880", icone: "", icone2x: "" }
  }

  // ─── Les filtres ─────────────────────────────────────────────────────────────────────
  passe(p) {
    const f = this.filtre
    if (f.categories.size && !f.categories.has(p.categorie)) return false
    if (f.texte && !p.recherche.includes(f.texte)) return false
    if (f.favoris && !this.favoris.has(p.id)) return false
    return true
  }

  appliquerFiltres() {
    if (this.grappes) {
      this.grappes.clearLayers()
      this.grappes.addLayers(this.poses.filter((p) => this.passe(p)).map((p) => p.marqueur))
    }
    this.majVolet()
  }

  basculerCategorie({ params: { cle } }) {
    const c = this.filtre.categories
    c.has(cle) ? c.delete(cle) : c.add(cle)
    this.categorieTargets.forEach((b) => b.setAttribute("aria-pressed", String(c.has(b.dataset.cle))))
    this.appliquerFiltres()
  }

  rechercher() {
    this.filtre.texte = normaliser(this.rechercheTarget.value.trim())
    this.appliquerFiltres()
  }

  reinitialiser() {
    this.filtre = { categories: new Set(), texte: "", favoris: false }
    this.rechercheTarget.value = ""
    this.categorieTargets.forEach((b) => b.setAttribute("aria-pressed", "false"))
    this.majOnglets()
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
    if (p?.marqueur && this.carte) {
      this.selectionner(p.id)
      this.grappes.zoomToShowLayer(p.marqueur, () => this.carte.panTo(p.latlng))
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

  // Met en avant le marqueur de la fiche survolée, ou la grappe qui le contient.
  marquerSurvol() {
    if (!this.grappes) return
    this.carteTarget.querySelectorAll(".acc-survole").forEach((el) => el.classList.remove("acc-survole"))
    for (const id of [this.survol, this.selection]) {
      const p = id && this.points.find((q) => q.id === id)
      if (!p?.marqueur || !this.grappes.hasLayer(p.marqueur)) continue
      this.grappes.getVisibleParent(p.marqueur)?.getElement()?.classList.add("acc-survole")
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
    // Sur mobile, l'en-tête et les puces recouvrent la carte : on cadre dans ce qui reste visible.
    const bureau = window.matchMedia(BUREAU).matches
    const haut = bureau ? 80 : (this.element.querySelector(".acc-tete")?.offsetHeight || 0) + 20
    const options = { paddingTopLeft: [30, haut], paddingBottomRight: [bureau ? 90 : 80, bureau ? 40 : 110], maxZoom: 6 }
    if (pts.length) this.carte.fitBounds(this.L.latLngBounds(pts), options)
    else this.carte.fitBounds(this.bornes)
  }

  // Centre la carte sur CENTRE_INITIAL (projeté dans la mosaïque) au zoom ZOOM_INITIAL.
  vueInitiale() {
    const [x, y] = this.projection.versL93(CENTRE_INITIAL.lon, CENTRE_INITIAL.lat)
    const [px, py] = this.projection.pixelL93(x, y)
    this.carte.setView(this.carte.unproject(this.L.point(px, py), NIVEAU_MAX), ZOOM_INITIAL, { animate: false })
  }

  // Réglage de la vue : ?debug_vue=1 affiche le centre (lat/lon) et le zoom courants. Sans ce paramètre, rien.
  afficherDebugVue() {
    if (new URLSearchParams(window.location.search).get("debug_vue") !== "1") return
    const encart = document.createElement("output")
    encart.className = "acc-debug-vue"
    this.carteTarget.parentElement.appendChild(encart)
    const maj = () => {
      const c = this.carte.getCenter()
      const { x, y } = this.carte.project(c, NIVEAU_MAX)
      const [lon, lat] = this.projection.versWGS84(x, y)
      encart.textContent = `centre ${lat.toFixed(5)}, ${lon.toFixed(5)} · zoom ${this.carte.getZoom()}`
    }
    this.carte.on("move zoom", maj)
    maj()
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
