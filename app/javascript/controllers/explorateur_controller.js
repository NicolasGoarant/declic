// Pages Opportunités et Belles Histoires (/labo/opportunites, /labo/belles-histoires) : recherche,
// filtres rapides, tri et grille de cartes. Cohabite avec diorama_controller sur le même élément
// (data-controller="diorama explorateur") : les mêmes boutons de catégorie pilotent les deux (voir
// labo/_filtre_categories) ; la géolocalisation est partagée via l'événement `diorama:localise`
// (bouton « Me localiser » de la carte) ou demandée ici directement (pastille « À proximité »).
import { Controller } from "@hotwired/stimulus"
import { demander } from "geoloc_auto"

const CLE_FAVORIS = "declic:favoris" // même clé que diorama_controller.js et fiche_controller.js
const JOUR_MS = 24 * 60 * 60 * 1000

export default class extends Controller {
  static values = { points: Array }
  static targets = [
    "grille", "modele", "compteur", "vide", "recherche", "tri", "categorie", "toutes",
    "rayon", "rayonValeur", "rayonBloc", "proximitePille", "proximiteMessage", "triPille", "panneau"
  ]

  connect() {
    // Mobile (375 px) : le panneau recherche/filtres démarre replié, sous la carte (<details>, repli
    // natif au clavier comme à la souris) ; sur bureau, il reste ouvert (attribut `open` posé dans la vue).
    if (this.hasPanneauTarget && window.matchMedia("(max-width: 699.98px)").matches) {
      this.panneauTarget.removeAttribute("open")
    }
    this.filtre = {
      categories: new Set(), texte: "", semaine: false, nouveautes: false, proximite: false,
      rayon: this.hasRayonTarget ? Number(this.rayonTarget.value) : 25,
      tri: this.hasTriTarget ? this.triTarget.value : "recentes"
    }
    this.position = null
    this.favoris = this.lireFavoris()
    this.points = this.pointsValue
    this.rendre()
  }

  // ─── Recherche et tri (liste déroulante « Plus récentes / Plus proches / Date ») ─────────
  chercher(evenement) {
    this.filtre.texte = evenement.target.value.trim().toLowerCase()
    this.rendre()
  }

  trier(evenement) {
    this.filtre.tri = evenement.target.value
    this.rendre()
  }

  // Pastilles de tri (Belles Histoires : « Récentes », « Par thématique »).
  choisirTri({ params: { valeur } }) {
    this.filtre.tri = valeur
    if (this.hasTriTarget) this.triTarget.value = valeur
    this.rendre()
  }

  // ─── Catégories : synchronisées avec diorama#basculerCategorie sur les mêmes boutons ─────
  basculerCategorie({ params: { cle } }) {
    const c = this.filtre.categories
    c.has(cle) ? c.delete(cle) : c.add(cle)
    this.rendre()
  }

  toutesCategories() {
    this.filtre.categories.clear()
    this.rendre()
  }

  // ─── Pastilles rapides (Opportunités : « Cette semaine », « Nouveautés ») ────────────────
  basculerSemaine(evenement) {
    this.filtre.semaine = !this.filtre.semaine
    evenement.currentTarget.setAttribute("aria-pressed", String(this.filtre.semaine))
    this.rendre()
  }

  basculerNouveautes(evenement) {
    this.filtre.nouveautes = !this.filtre.nouveautes
    evenement.currentTarget.setAttribute("aria-pressed", String(this.filtre.nouveautes))
    this.rendre()
  }

  // ─── À proximité : demande sa propre géolocalisation si « Me localiser » n'a pas déjà répondu ──
  basculerProximite(evenement) {
    if (!this.position) { this.demanderLocalisation(); return }
    this.filtre.proximite = !this.filtre.proximite
    this.majPilleProximite()
    this.rendre()
  }

  // La demande passe par geoloc_auto (partagée avec « Me localiser ») : la position revient par diorama:localise.
  demanderLocalisation() {
    this.proximiteEnAttente = true
    demander(() => { this.proximiteEnAttente = false; this.signalerEchecLocalisation() })
  }

  // Écoute diorama:localise (bouton « Me localiser » de la carte) : une seule permission pour les deux.
  surLocalisation({ detail: { lat, lon } }) {
    const premiere = !this.position
    this.position = { lat, lon }
    // Position connue pour la première fois : les résultats passent par distance (le menu reste modifiable).
    if (premiere && this.hasTriTarget && this.triTarget.querySelector('option[value="proches"]')) {
      this.filtre.tri = "proches"
      this.triTarget.value = "proches"
    }
    if (this.proximiteEnAttente) { // pastille « À proximité » cliquée avant que la position soit connue
      this.proximiteEnAttente = false
      this.filtre.proximite = true
      this.majPilleProximite()
    }
    if (this.hasRayonBlocTarget) this.rayonBlocTarget.hidden = false
    if (this.hasProximiteMessageTarget) this.proximiteMessageTarget.hidden = true
    this.rendre()
  }

  surEchecLocalisation() {
    this.signalerEchecLocalisation()
  }

  signalerEchecLocalisation() {
    if (this.hasProximiteMessageTarget) {
      this.proximiteMessageTarget.hidden = false
      this.proximiteMessageTarget.textContent =
        "Localisation refusée ou indisponible : le filtre « à proximité » reste inactif."
    }
  }

  majPilleProximite() {
    this.proximitePilleTargets.forEach((b) => b.setAttribute("aria-pressed", String(this.filtre.proximite)))
  }

  changerRayon(evenement) {
    this.filtre.rayon = Number(evenement.target.value)
    if (this.hasRayonValeurTarget) this.rayonValeurTarget.textContent = `${this.filtre.rayon} km`
    this.rendre()
  }

  // ─── Filtrage, tri, rendu ─────────────────────────────────────────────────────────────
  distanceKm(lat1, lon1, lat2, lon2) {
    const R = 6371, toRad = (d) => (d * Math.PI) / 180
    const dLat = toRad(lat2 - lat1), dLon = toRad(lon2 - lon1)
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
    return 2 * R * Math.asin(Math.sqrt(a))
  }

  passe(p) {
    const f = this.filtre
    if (f.categories.size && !f.categories.has(p.categorie)) return false
    if (f.texte) {
      const cible = `${p.titre} ${p.commune ?? ""} ${p.extrait ?? ""}`.toLowerCase()
      if (!cible.includes(f.texte)) return false
    }
    if (f.semaine) {
      if (!p.debut) return false
      const debut = new Date(p.debut).getTime()
      if (debut - Date.now() > 7 * JOUR_MS || debut < Date.now() - JOUR_MS) return false
    }
    if (f.nouveautes && (!p.cree_le || Date.now() - new Date(p.cree_le).getTime() > 30 * JOUR_MS)) return false
    if (f.proximite && this.position) {
      if (!Number.isFinite(p.latitude) || !Number.isFinite(p.longitude)) return false
      if (this.distanceKm(this.position.lat, this.position.lon, p.latitude, p.longitude) > f.rayon) return false
    }
    return true
  }

  ordonner(liste) {
    const t = this.filtre.tri
    if (t === "proches" && this.position) {
      return [...liste].sort((a, b) =>
        this.distanceKm(this.position.lat, this.position.lon, a.latitude, a.longitude) -
        this.distanceKm(this.position.lat, this.position.lon, b.latitude, b.longitude))
    }
    if (t === "date") {
      return [...liste].sort((a, b) => new Date(a.debut || 8640000000000000) - new Date(b.debut || 8640000000000000))
    }
    if (t === "thematique") {
      return [...liste].sort((a, b) => (a.categorie_libelle || "").localeCompare(b.categorie_libelle || "", "fr"))
    }
    // recentes (par défaut) : les fiches les plus récemment publiées d'abord.
    return [...liste].sort((a, b) => new Date(b.cree_le || 0) - new Date(a.cree_le || 0))
  }

  rendre() {
    const resultats = this.ordonner(this.points.filter((p) => this.passe(p)))

    if (this.hasCompteurTarget) {
      this.compteurTarget.textContent = `${resultats.length} résultat${resultats.length > 1 ? "s" : ""}`
    }
    if (this.hasVideTarget) this.videTarget.hidden = resultats.length > 0

    this.grilleTarget.replaceChildren(...resultats.map((p) => this.carteDom(p)))

    this.categorieTargets.forEach((b) => b.setAttribute("aria-pressed", String(this.filtre.categories.has(b.dataset.cle))))
    if (this.hasToutesTarget) this.toutesTarget.setAttribute("aria-pressed", String(this.filtre.categories.size === 0))
    this.triPilleTargets.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.valeur === this.filtre.tri)))
  }

  carteDom(p) {
    const noeud = this.modeleTarget.content.firstElementChild.cloneNode(true)
    noeud.dataset.id = p.id

    const photo = noeud.querySelector("[data-photo]")
    const picto = noeud.querySelector("[data-picto]")
    if (p.photo && photo) {
      photo.src = p.photo
      photo.alt = p.titre
      photo.hidden = false
      if (picto) picto.hidden = true
    } else if (picto) {
      picto.src = p.categorie_icone
      picto.srcset = p.categorie_icone2x ? `${p.categorie_icone2x} 2x` : ""
      picto.style.setProperty("--c", p.categorie_couleur || "#6b6880")
      picto.hidden = false
      if (photo) photo.hidden = true
    }

    const cat = noeud.querySelector("[data-categorie]")
    if (cat && p.categorie_libelle) { cat.textContent = p.categorie_libelle; cat.style.setProperty("--c", p.categorie_couleur) }

    const titre = noeud.querySelector("[data-titre]")
    if (titre) { titre.textContent = p.titre; titre.href = p.url }

    const commune = noeud.querySelector("[data-commune]")
    if (commune) commune.textContent = p.commune || ""

    const quand = noeud.querySelector("[data-quand]")
    if (quand) quand.textContent = p.date_affichee || ""

    const horaireBloc = noeud.querySelector("[data-horaire-bloc]")
    const horaire = noeud.querySelector("[data-horaire]")
    if (horaire) {
      if (p.horaire) { horaire.textContent = p.horaire } else if (horaireBloc) { horaireBloc.hidden = true }
    }

    const extrait = noeud.querySelector("[data-extrait]")
    if (extrait) extrait.textContent = p.extrait || ""

    const citationBloc = noeud.querySelector("[data-citation-bloc]")
    const citation = noeud.querySelector("[data-citation]")
    if (citation) {
      if (p.citation) { citation.textContent = p.citation } else if (citationBloc) { citationBloc.hidden = true }
    }

    const lien = noeud.querySelector("[data-lien]")
    if (lien) lien.href = p.url

    const signet = noeud.querySelector("[data-signet]")
    if (signet) {
      const favori = this.favoris.has(p.id)
      signet.setAttribute("aria-pressed", String(favori))
      signet.setAttribute("aria-label", favori ? `Retirer « ${p.titre} » des favoris` : `Garder « ${p.titre} » en favori`)
      signet.addEventListener("click", () => this.basculerFavori(p.id, signet, p.titre))
    }

    return noeud
  }

  basculerFavori(id, bouton, titre) {
    this.favoris.has(id) ? this.favoris.delete(id) : this.favoris.add(id)
    try { localStorage.setItem(CLE_FAVORIS, JSON.stringify([...this.favoris])) } catch { /* stockage indisponible */ }
    const favori = this.favoris.has(id)
    bouton.setAttribute("aria-pressed", String(favori))
    bouton.setAttribute("aria-label", favori ? `Retirer « ${titre} » des favoris` : `Garder « ${titre} » en favori`)
  }

  lireFavoris() {
    try { return new Set(JSON.parse(localStorage.getItem(CLE_FAVORIS) || "[]")) } catch { return new Set() }
  }
}
