// Les effets de VUE du diorama (nancy-3d nuit-chaude-v1) : ils portent sur la vue assemblée, jamais sur une
// dalle, et ne demandent donc rien aux tuiles (nancy-3d docs/industrialisation.md § 5c). Réglages : VUE.
//
// Halo — en mode « vue », le volet « halo » reçoit la couche d'émission (ambiance.js, creerCoucheEmission) ; le flou
// et le gain y sont des filtres CSS du VOLET, donc le flou traverse les bords de dalle, et le volet est posé en
// « écran » sur le fond, comme le halo du banc (nancy-3d rapports/nuit-chaude-v1/scripts/vue.py). En mode « dalle »
// (en vigueur), le même flou et le même gain sont appliqués dans chaque dalle : voir haloMode.
//
// Tilt-shift — l'écart-type voulu à la ligne d'écran y (−1 en haut, +1 en bas) vaut
//   s(y) = sigma_max · smoothstep((|y| − bande) / (1 − bande)),
// celui de vue.py. Un backdrop-filter n'a qu'un rayon : on empile `niveaux` volets plein écran, le j-ième flouté de
// δj = √(σj² − σj−1²) avec σj = sigma_max · j / niveaux, et masqué là où s(y) < σj−1 (rampe jusqu'à σj). Chaque
// volet floute ce que les précédents ont déjà flouté, et deux flous gaussiens successifs font un flou dont les
// VARIANCES s'ajoutent : là où les j premiers volets sont pleins, le flou vaut exactement σj ; entre deux paliers,
// c'est un mélange des deux flous voisins (approximation déclarée). Le tout est un volet de la carte, sous les pins
// (600) et la météo (450), au-dessus des vivants (445) : les repères et la pluie restent nets.
import { VUE } from "diorama/reglages"

const Z_HALO = 250   // au-dessus des dalles (200), sous les bateaux (440) et les vivants (445)
const Z_TILT = 448

// Coupé par ?halo=0 (crochet d'instrument déclaré, comme ?tilt=0 : témoin du banc de cadence).
export function haloPermis() { return new URLSearchParams(window.location.search).get("halo") !== "0" }

// Où le halo est flouté : « dalle » (réglage en vigueur : chaque dalle d'ambiance floute sa propre émission une fois,
// à sa création, et la compose en écran sur elle-même, ambiance.js) ou « vue » (volet filtré, ci-dessous, qui
// traverse les bords de dalle mais se recompose à chaque image) ; null si coupé. ?halo=vue|dalle force le mode
// (crochet d'instrument déclaré). En déplacement, « dalle » rend ×1,44 la cadence de la nuit complète (5 rondes
// sur 5) au prix d'une couture du halo aux bords de dalle : nancy-3d rapports/nuit-chaude-v1/rapport-v6.md.
export function haloMode() {
  const q = new URLSearchParams(window.location.search).get("halo")
  if (q === "0") return null
  return q === "vue" || q === "dalle" ? q : VUE.halo.mode
}

// Le volet du halo de `carte` (créé une fois).
export function voletHalo(carte) {
  let volet = carte.getPane("halo")
  if (!volet) {
    volet = carte.createPane("halo")
    const h = VUE.halo
    volet.style.zIndex = Z_HALO
    volet.style.pointerEvents = "none"
    volet.style.filter = `blur(${h.sigma_px}px) brightness(${h.gain})`
    volet.style.mixBlendMode = "screen"
  }
  return volet
}

function smoothstep(t) { t = Math.min(1, Math.max(0, t)); return t * t * (3 - 2 * t) }

// Écart-type voulu à la hauteur relative v ∈ [0, 1] de la vue (0 en haut).
export function sigmaTilt(v, { bande, sigma_max_px } = VUE.tilt_shift) {
  return sigma_max_px * smoothstep((Math.abs(v * 2 - 1) - bande) / (1 - bande))
}

// Le masque du j-ième volet (1 ≤ j ≤ niveaux) : dégradé vertical, opaque là où s(y) ≥ σj, transparent sous σj−1.
function masque(j, reglage, pas = 80) {
  const n = reglage.niveaux, sj = reglage.sigma_max_px * j / n, sp = reglage.sigma_max_px * (j - 1) / n
  const arrets = []
  for (let k = 0; k <= pas; k++) {
    const v = k / pas, a = Math.min(1, Math.max(0, (sigmaTilt(v, reglage) - sp) / (sj - sp)))
    arrets.push(`rgba(0,0,0,${a.toFixed(4)}) ${(v * 100).toFixed(2)}%`)
  }
  return `linear-gradient(to bottom, ${arrets.join(", ")})`
}

export class TiltShift {
  // Coupé par ?tilt=0 (crochet d'instrument déclaré : témoin du banc de cadence et comparaison à l'œil).
  static permis() { return new URLSearchParams(window.location.search).get("tilt") !== "0" }

  constructor(L, carte, reglage = VUE.tilt_shift) {
    this.L = L
    this.carte = carte
    const volet = carte.getPane("tilt") || carte.createPane("tilt")
    volet.style.zIndex = Z_TILT
    volet.style.pointerEvents = "none"
    this.cadre = L.DomUtil.create("div", "diorama-tilt", volet)
    Object.assign(this.cadre.style, { position: "absolute", left: "0", top: "0", pointerEvents: "none" })
    for (let j = 1; j <= reglage.niveaux; j++) {
      const sj = reglage.sigma_max_px * j / reglage.niveaux, sp = reglage.sigma_max_px * (j - 1) / reglage.niveaux
      const delta = Math.sqrt(sj * sj - sp * sp), m = masque(j, reglage)
      const d = L.DomUtil.create("div", "", this.cadre)
      Object.assign(d.style, { position: "absolute", inset: "0", pointerEvents: "none",
        backdropFilter: `blur(${delta.toFixed(3)}px)`, webkitBackdropFilter: `blur(${delta.toFixed(3)}px)`,
        maskImage: m, webkitMaskImage: m })
    }
    this.placer = () => {
      const t = carte.getSize()
      this.cadre.style.width = `${t.x}px`
      this.cadre.style.height = `${t.y}px`
      L.DomUtil.setPosition(this.cadre, carte.containerPointToLayerPoint([0, 0]))
    }
    carte.on("move zoomend viewreset resize", this.placer)
    this.placer()
  }

  detruire() {
    this.carte.off("move zoomend viewreset resize", this.placer)
    this.cadre.remove()
  }
}
