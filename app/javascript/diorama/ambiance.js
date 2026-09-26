// La couche d'AMBIANCE, portée de nancy-3d/rapports/pyramide-v1/ambiance-v3.js : un grade
// WebGL par dalle. Elle REMPLACE la couche de fond, comme la maquette blanche : les deux
// sont exclusives.
//
// Le grade est celui que nancy-3d/scripts/caler_ambiance.py écrit en JSON (format
// « nancy-3d/ambiance ») : une suite de règles, chacune un affine Lab par canal et une force,
//     lab' = lab + force * ((lab - ms) / es * er + mr - lab)
// appliquée au pixel par la PREMIÈRE règle dont la classe le contient. Classes : 0 exclu,
// 1 sol, 2 volume, 3 feuillage. La classe vient de la carte de propriété au niveau 8, du
// masque du bâti aux niveaux 6-7, et ailleurs tout pixel non transparent est un volume.
import { COTE, creerCache } from "diorama/couches"

const REGLES_MAX = 4
const SOURCE_VS = "attribute vec2 p; varying vec2 uv; void main(){ uv = p * 0.5 + 0.5; gl_Position = vec4(p, 0.0, 1.0); }"

const SOURCE_FS = [
  "precision highp float;",
  "uniform sampler2D tBase, tOrig, tClasse;",
  "uniform int modeClasse, n;",
  "uniform vec3 cl[4], ms[4], es[4], mr[4], er[4]; uniform float force[4];",
  "varying vec2 uv;",
  "vec3 lin(vec3 c){ return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }",
  "vec3 gam(vec3 c){ c = clamp(c, 0.0, 1.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0/2.4)) - 0.055, step(0.0031308, c)); }",
  "float f(float x){ return x > 0.008856 ? pow(x, 1.0/3.0) : 7.787 * x + 16.0/116.0; }",
  "float fi(float x){ return x > 0.206893 ? x*x*x : (x - 16.0/116.0) / 7.787; }",
  "vec3 versLab(vec3 c){ vec3 l = lin(c);",
  "  vec3 xyz = mat3(0.412453, 0.212671, 0.019334, 0.357580, 0.715160, 0.119193, 0.180423, 0.072169, 0.950227) * l;",
  "  xyz /= vec3(0.950456, 1.0, 1.088754);",
  "  float fx = f(xyz.x), fy = f(xyz.y), fz = f(xyz.z);",
  "  float L = xyz.y > 0.008856 ? 116.0 * fy - 16.0 : 903.3 * xyz.y;",
  "  return vec3(L, 500.0 * (fx - fy), 200.0 * (fy - fz)); }",
  "vec3 depuisLab(vec3 lab){ float fy = (lab.x + 16.0) / 116.0, fx = fy + lab.y / 500.0, fz = fy - lab.z / 200.0;",
  "  vec3 xyz = vec3(fi(fx), fi(fy), fi(fz)) * vec3(0.950456, 1.0, 1.088754);",
  "  vec3 l = mat3(3.240479, -0.969256, 0.055648, -1.537150, 1.875992, -0.204043, -0.498535, 0.041556, 1.057311) * xyz;",
  "  return gam(l); }",
  "bool feuillage(vec3 c){ float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn;",
  "  if (mx <= 0.0 || d <= 0.0) return false; float s = d / mx; if (s <= 0.12) return false;",
  "  float h; if (mx == c.r) h = 60.0 * (c.g - c.b) / d; else if (mx == c.g) h = 120.0 + 60.0 * (c.b - c.r) / d;",
  "  else h = 240.0 + 60.0 * (c.r - c.g) / d; if (h < 0.0) h += 360.0;",
  "  return h >= 60.0 && h <= 130.0; }",
  "void main(){",
  "  vec4 c = texture2D(tBase, uv); vec3 o = texture2D(tOrig, uv).rgb;",
  "  float classe;",
  "  if (modeClasse == 0) { float k = floor(texture2D(tClasse, uv).r * 255.0 + 0.5);",
  "    classe = (k == 1.0 || k == 3.0) ? 1.0 : ((k == 2.0 || k == 4.0) ? 2.0 : 0.0); }",
  "  else if (modeClasse == 1) classe = texture2D(tClasse, uv).r > 0.5 ? 2.0 : 1.0;",
  "  else classe = 2.0;",
  "  if (c.a < 0.5) classe = 0.0;",
  "  if (classe > 0.0 && feuillage(o)) classe = 3.0;",
  "  vec3 lab = versLab(c.rgb); bool fait = false;",
  "  for (int i = 0; i < 4; i++) {",
  "    if (i >= n || fait || classe == 0.0) continue;",
  "    float dedans = classe == 1.0 ? cl[i].x : (classe == 2.0 ? cl[i].y : cl[i].z);",
  "    if (dedans < 0.5) continue;",
  "    lab = lab + force[i] * ((lab - ms[i]) / es[i] * er[i] + mr[i] - lab); fait = true; }",
  "  gl_FragColor = fait ? vec4(depuisLab(lab), c.a) : c; }"
].join("\n")

function compiler(gl, type, source) {
  const s = gl.createShader(type)
  gl.shaderSource(s, source)
  gl.compileShader(s)
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(`shader : ${gl.getShaderInfoLog(s)}`)
  return s
}

function texture(gl) {
  const t = gl.createTexture()
  gl.bindTexture(gl.TEXTURE_2D, t)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  return t
}

// UN SEUL contexte WebGL pour toute la couche ; chaque dalle est calculée ici puis recopiée
// dans son propre canevas 2D.
class Moteur {
  constructor() {
    const toile = document.createElement("canvas")
    toile.width = toile.height = COTE
    const gl = toile.getContext("webgl", { premultipliedAlpha: false, preserveDrawingBuffer: true })
    if (!gl) throw new Error("WebGL indisponible")
    const p = gl.createProgram()
    gl.attachShader(p, compiler(gl, gl.VERTEX_SHADER, SOURCE_VS))
    gl.attachShader(p, compiler(gl, gl.FRAGMENT_SHADER, SOURCE_FS))
    gl.linkProgram(p)
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(`programme : ${gl.getProgramInfoLog(p)}`)
    gl.useProgram(p)
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer())
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)
    const loc = gl.getAttribLocation(p, "p")
    gl.enableVertexAttribArray(loc)
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0)
    this.toile = toile
    this.gl = gl
    this.p = p
    this.tex = [texture(gl), texture(gl), texture(gl)]
    this.vide = document.createElement("canvas")
    this.vide.width = this.vide.height = 1
    ;["tBase", "tOrig", "tClasse"].forEach((nom, k) => gl.uniform1i(gl.getUniformLocation(p, nom), k))
  }

  u(nom) { return this.gl.getUniformLocation(this.p, nom) }

  traiter(base, classe, mode, regles) {
    const gl = this.gl
    const images = [base, base, classe || this.vide]
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    images.forEach((image, k) => {
      gl.activeTexture(gl.TEXTURE0 + k)
      gl.bindTexture(gl.TEXTURE_2D, this.tex[k])
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)
    })
    const cl = [], ms = [], es = [], mr = [], er = [], fo = []
    for (let i = 0; i < REGLES_MAX; i++) {
      const r = regles[i]
      const v = r ? r.valeurs_classe : []
      cl.push(v.includes(1) ? 1 : 0, v.includes(2) ? 1 : 0, v.includes(3) ? 1 : 0)
      ms.push(...(r ? r.ms : [0, 0, 0])); es.push(...(r ? r.es : [1, 1, 1]))
      mr.push(...(r ? r.mr : [0, 0, 0])); er.push(...(r ? r.er : [1, 1, 1]))
      fo.push(r ? r.force : 0)
    }
    gl.uniform1i(this.u("modeClasse"), mode)
    gl.uniform1i(this.u("n"), Math.min(regles.length, REGLES_MAX))
    gl.uniform3fv(this.u("cl"), cl); gl.uniform3fv(this.u("ms"), ms); gl.uniform3fv(this.u("es"), es)
    gl.uniform3fv(this.u("mr"), mr); gl.uniform3fv(this.u("er"), er); gl.uniform1fv(this.u("force"), fo)
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    gl.viewport(0, 0, COTE, COTE)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    return this.toile
  }
}

function charger(url) {
  return new Promise((ok) => {
    if (!url) { ok(null); return }
    const image = new Image()
    image.crossOrigin = "anonymous"
    image.onload = () => ok(image)
    image.onerror = () => ok(null)
    image.src = url
  })
}

// Lit et vérifie un fichier de paramètres d'ambiance.
export async function lireAmbiance(url) {
  const reponse = await fetch(url)
  if (!reponse.ok) throw new Error(`${url} : HTTP ${reponse.status}`)
  const json = await reponse.json()
  if (json.format !== "nancy-3d/ambiance") throw new Error(`${url} : format ${json.format}`)
  return json
}

// opts : dalle(chemin), propriete(chemin), masque(chemin) → URL ; estListee(coords) ;
// masqueListe(coords) ; parametres (Promise du JSON) ; options (options de couche Leaflet).
export function creerCoucheAmbiance(L, opts) {
  let moteur = null
  const cache = creerCache() // un étalonnage par dalle, pas un de plus
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      const toile = document.createElement("canvas")
      toile.width = toile.height = COTE
      if (!opts.estListee(coords)) {
        setTimeout(() => fini(null, toile), 0)
        return toile
      }
      const chemin = `${coords.z}/${coords.x}/${coords.y}`
      if (cache.lire(chemin, toile)) { setTimeout(() => fini(null, toile), 0); return toile }
      let urlClasse = null, mode = 2
      if (coords.z === 8) { urlClasse = opts.propriete(chemin); mode = 0 }
      else if (coords.z >= 6 && opts.masqueListe(coords)) { urlClasse = opts.masque(chemin); mode = 1 }
      Promise.all([opts.parametres, charger(opts.dalle(chemin)), charger(urlClasse)])
        .then(([parametres, base, classe]) => {
          if (!base) { fini(new Error("dalle absente"), toile); return }
          const regles = parametres?.regles || []
          const ctx = toile.getContext("2d", { willReadFrequently: true })
          if (!regles.length) { ctx.drawImage(base, 0, 0); fini(null, toile); return }
          moteur ||= new Moteur()
          ctx.drawImage(moteur.traiter(base, classe, classe ? mode : 2, regles), 0, 0)
          cache.garder(chemin, toile)
          fini(null, toile)
        })
        .catch((erreur) => fini(erreur, toile))
      return toile
    }
  })
  return new Couche(opts.options)
}
