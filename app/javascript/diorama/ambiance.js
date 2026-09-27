// La couche d'AMBIANCE : un étalonnage WebGL par dalle, qui REMPLACE la couche de fond (comme la
// maquette blanche : les deux sont exclusives). Elle cumule trois réglages indépendants, dans cet
// ordre (valeurs : diorama/reglages) :
//   1. saison : hiver (étalonnage publié) ou automne (feuillages seulement, voir plus bas) ;
//   2. météo : pluie (sol plus sombre et plus contrasté) ou neige (toits blanchis via masque-bati) ;
//   3. moment : heure bleue (étalonnage publié), aube, heure dorée ou nuit (paramétriques) ; la nuit
//      allume ensuite ses lumières, l'heure bleue aussi, à 40 % : la carte de lumière de la dalle
//      (diorama/lampadaires : nappes, cœurs, places) posée en mélange « écran », les façades
//      réchauffées depuis leur pied, les fenêtres ; puis les feux des mâts, dessinés en 2D.
//
// Façades : aucune donnée ne les distingue des toits. Le shader les déduit : un pixel bâti dont le sol
// est juste en dessous à l'écran (moins d'une hauteur de façade) est une façade vue de face. Pour les
// pixels du bas de la dalle, il lit aussi la classe de la dalle du dessous (tClasseBas).
//
// Les étalonnages publiés sont ceux que nancy-3d/scripts/caler_ambiance.py écrit en JSON (format
// « nancy-3d/ambiance ») : une suite de règles, chacune un affine Lab par canal et une force,
//     lab' = lab + force * ((lab - ms) / es * er + mr - lab)
// appliquée au pixel par la PREMIÈRE règle dont la classe le contient. Classes : 0 exclu,
// 1 sol, 2 volume, 3 feuillage. La classe vient de la carte de propriété au niveau 8, du
// masque du bâti aux niveaux 6-7, et ailleurs tout pixel non transparent est un volume.
//
// L'automne n'applique la règle « feuillage » de son étalonnage qu'aux pixels du masque des arbres
// (masque-arbres, niveaux 6 à 8) ; sans ce masque, aux verts sombres (repli). Chaque arbre prend
// ensuite sa propre teinte, du jaune au roux : une cellule de Voronoï de la taille d'un houppier,
// calée sur les pixels du niveau 8, donc fixe au sol quel que soit le zoom ou le déplacement.
import { COTE, creerCache, comblerInterstices } from "diorama/couches"
import { carteDeLumiere, dessinerFeux, DEBORD } from "diorama/lampadaires"
import { MOMENTS, PUBLIES, AUTOMNE, PLUIE, NEIGE, LAMPADAIRES } from "diorama/reglages"

const REGLES_MAX = 3 // par étalonnage publié (hiver : 2, heure bleue et automne : 1)
const NIVEAU_MAX = 8
const SOURCE_VS = "attribute vec2 p; varying vec2 uv; void main(){ uv = p * 0.5 + 0.5; gl_Position = vec4(p, 0.0, 1.0); }"

// Une suite de règles publiées, sous le préfixe `x` (s : saison, m : moment).
const reglesGLSL = (x) =>
  `uniform int n${x}; uniform vec3 ${x}Cl[${REGLES_MAX}], ${x}Ms[${REGLES_MAX}], ${x}Es[${REGLES_MAX}], ` +
  `${x}Mr[${REGLES_MAX}], ${x}Er[${REGLES_MAX}]; uniform float ${x}Force[${REGLES_MAX}];\n` +
  `vec3 regles_${x}(vec3 lab, float classe){ bool fait = false;\n` +
  `  for (int i = 0; i < ${REGLES_MAX}; i++) {\n` +
  `    if (i >= n${x} || fait || classe == 0.0) continue;\n` +
  `    float dedans = classe == 1.0 ? ${x}Cl[i].x : (classe == 2.0 ? ${x}Cl[i].y : ${x}Cl[i].z);\n` +
  `    if (dedans < 0.5) continue;\n` +
  `    lab = lab + ${x}Force[i] * ((lab - ${x}Ms[i]) / ${x}Es[i] * ${x}Er[i] + ${x}Mr[i] - lab); fait = true; }\n` +
  `  return lab; }`

const SOURCE_FS = [
  "precision highp float;",
  "uniform sampler2D tBase, tClasse, tArbres, tClasseBas, tLum;",
  "uniform int modeClasse;   // 0 propriété (niveau 8), 1 masque du bâti, 2 aucune",
  "uniform vec2 origine;     // coin haut-gauche de la dalle, en pixels du niveau 8",
  "uniform float echelle;    // pixels du niveau 8 par pixel de la dalle",
  "uniform int saison;       // 0 aucune, 1 règles publiées (hiver), 2 automne",
  "uniform int modeArbres;   // 1 masque des arbres, 0 repli sur les verts sombres",
  "uniform vec4 automne;     // intensité, variation de teinte (rad), variation de clarté, taille d'arbre",
  "uniform vec4 repli;       // teinte min, teinte max, saturation min, valeur max",
  "uniform float repliForce; // part de l'intensité en repli (moitié)",
  "uniform int meteo;        // 0 clair, 1 pluie, 2 neige",
  "uniform vec4 pluie;       // luminosité et contraste du sol, saturation, luminosité des volumes",
  "uniform float pluieVoile; // assombrissement léger de toute la carte pendant la pluie",
  "uniform vec4 neige;       // toits, sol",
  "uniform vec3 neigeCouleur;",
  "uniform int moment;       // 0 aucun, 1 règles publiées (heure bleue), 2 paramétrique",
  "uniform vec3 balance, grade; uniform vec4 voile; // grade : saturation, contraste, luminosité",
  "uniform vec4 parcs;       // couleur des parcs la nuit, et sa part",
  "uniform int lumieres;     // 1 : carte de lumière (tLum, COTE × (COTE + debord)) à poser",
  "uniform int classeBas;    // 1 : classe de la dalle du dessous lue (tClasseBas)",
  "uniform float lumForce, debord;",
  "uniform vec3 nappeCouleur, coeurCouleur, placeCouleur, gains;",
  "uniform vec3 eclairage;   // gain de la lumière sur la couleur du jour, part du cœur, fenêtres au loin",
  "uniform float fidelite;   // part de la teinte du jour gardée sous la lampe",
  "uniform vec4 facade;      // hauteur (px du niveau 8), réchauffement, décroissance, part reçue par les toits",
  "uniform vec3 facadeCouleur, fenetreCouleur;",
  "uniform vec4 fenetres;    // part, taille de grappe (px du niveau 8), écart entre grappes, intensité",
  "uniform vec4 fenetreForme; // cellule (l, h), fenêtre (l, h), en px du niveau 8",
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
  "vec3 hsv(vec3 c){ float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn, h = 0.0;",
  "  if (d > 0.0) { if (mx == c.r) h = 60.0 * (c.g - c.b) / d; else if (mx == c.g) h = 120.0 + 60.0 * (c.b - c.r) / d;",
  "    else h = 240.0 + 60.0 * (c.r - c.g) / d; if (h < 0.0) h += 360.0; }",
  "  return vec3(h, mx > 0.0 ? d / mx : 0.0, mx); }",
  "bool feuillage(vec3 c){ vec3 k = hsv(c); return k.y > 0.12 && k.x >= 60.0 && k.x <= 130.0; }",
  "float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }",
  // Hachage sans sinus (Dave Hoskins) : stable sur les grandes coordonnées.
  "float hache(vec2 p){ vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }",
  "vec2 hache2(vec2 p){ return vec2(hache(p), hache(p + 17.31)); }",
  // Identifiant de l'arbre : la cellule de Voronoï la plus proche.
  "float arbre(vec2 q){ vec2 i = floor(q), fr = fract(q); float dmin = 9.0, id = 0.0;",
  "  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) { vec2 n = vec2(float(x), float(y));",
  "    vec2 d = n + hache2(i + n) - fr; float l = dot(d, d); if (l < dmin) { dmin = l; id = hache(i + n + 5.7); } }",
  "  return id; }",
  "float verts_sombres(vec3 o){ vec3 k = hsv(o);",
  "  return smoothstep(repli.x - 10.0, repli.x, k.x) * (1.0 - smoothstep(repli.y, repli.y + 10.0, k.x))",
  "       * smoothstep(repli.z, repli.z + 0.06, k.y) * (1.0 - smoothstep(repli.w, repli.w + 0.08, k.z)); }",
  // Pixel `p` de la dalle (y vers le bas), jusqu'à COTE px sous la dalle : bâti ou non.
  "float bati(vec2 p){ bool bas = p.y >= 256.0; if (bas) { if (classeBas == 0) return 0.0; p.y -= 256.0; }",
  "  vec2 q = vec2((floor(p.x) + 0.5) / 256.0, 1.0 - (floor(p.y) + 0.5) / 256.0);",
  "  float r = bas ? texture2D(tClasseBas, q).r : texture2D(tClasse, q).r;",
  "  if (modeClasse == 0) { float k = floor(r * 255.0 + 0.5); return (k == 2.0 || k == 4.0) ? 1.0 : 0.0; }",
  "  return r > 0.5 ? 1.0 : 0.0; }",
  // La lumière reçue en `p`, saturée en douceur ; `lumForce` (40 % à l'heure bleue) dose l'énergie, pas le
  // mélange : moins de portée, mais une lumière toujours dorée là où elle tombe.
  "vec3 lumiere(vec2 p){ vec3 l = texture2D(tLum, vec2(p.x / 256.0, 1.0 - p.y / (256.0 + debord))).rgb;",
  "  return 1.0 - exp(-gains * l * lumForce); }",
  "vec3 ecran(vec3 a, vec3 b){ return 1.0 - (1.0 - a) * (1.0 - clamp(b, 0.0, 1.0)); }",
  reglesGLSL("s"),
  reglesGLSL("m"),
  "void main(){",
  "  vec4 c = texture2D(tBase, uv);",
  "  if (c.a < 0.5) { gl_FragColor = c; return; }",
  "  vec3 o = c.rgb;",
  "  vec2 px = vec2(uv.x, 1.0 - uv.y) * 256.0;       // pixel de la dalle (y vers le bas)",
  "  vec2 monde = origine + px * echelle;            // pixel du niveau 8",
  // Classe du pixel, et part de toit (neige).
  "  float classe, toit;",
  "  if (modeClasse == 0) { float k = floor(texture2D(tClasse, uv).r * 255.0 + 0.5);",
  "    classe = (k == 1.0 || k == 3.0) ? 1.0 : ((k == 2.0 || k == 4.0) ? 2.0 : 0.0); toit = classe == 2.0 ? 1.0 : 0.0; }",
  "  else if (modeClasse == 1) { toit = texture2D(tClasse, uv).r; classe = toit > 0.5 ? 2.0 : 1.0; }",
  "  else { classe = 2.0; toit = -1.0; }",
  "  if (classe > 0.0 && feuillage(o)) classe = 3.0;",
  "  vec3 lab = versLab(o);",
  // 1. Saison.
  "  if (saison == 1) lab = regles_s(lab, classe);",
  "  else if (saison == 2) {",
  "    float w = (modeArbres == 1 ? texture2D(tArbres, uv).r : verts_sombres(o) * repliForce) * automne.x;",
  "    if (w > 0.0) {",
  "      vec3 a = lab + sForce[0] * ((lab - sMs[0]) / sEs[0] * sEr[0] + sMr[0] - lab);",
  "      float id = arbre(monde / automne.w), ang = (id * 2.0 - 1.0) * automne.y;",
  "      a.yz = mat2(cos(ang), sin(ang), -sin(ang), cos(ang)) * a.yz;",
  "      a.x += (hache(vec2(id * 91.0, 3.0)) * 2.0 - 1.0) * automne.z;",
  "      lab = mix(lab, a, w); } }",
  "  vec3 rgb = depuisLab(lab);",
  // 2. Météo.
  "  if (meteo == 1) {",
  "    float sol = classe == 2.0 ? (toit < 0.0 ? 0.5 : 0.0) : 1.0;",
  "    vec3 mouille = ((rgb - 0.5) * pluie.y + 0.5) * pluie.x;",
  "    mouille = mix(vec3(luma(mouille)), mouille, pluie.z);",
  "    rgb = mix(rgb * pluie.w, clamp(mouille, 0.0, 1.0), sol) * (1.0 - pluieVoile); }",
  "  else if (meteo == 2) {",
  "    float l = luma(rgb), bruit = 0.75 + 0.25 * hache(floor(monde / 3.0));",
  // Hors du masque du bâti (toit < 0) : tout ce qui n'est pas feuillage, dosé par la clarté, pour ne pas
  // laisser de lisière entre les dalles couvertes et les autres.
  "    float t = toit < 0.0 ? (classe == 3.0 ? 0.0 : 0.6 * smoothstep(0.25, 0.6, l)) : toit;",
  "    float w = max(t * neige.x * mix(0.55, 1.0, smoothstep(0.3, 0.75, l)) * bruit, neige.y);",
  "    rgb = mix(rgb, neigeCouleur * (0.72 + 0.32 * l), w); }",
  // 3. Moment.
  "  if (moment == 1) rgb = depuisLab(regles_m(versLab(rgb), classe));",
  "  else if (moment == 2) {",
  "    rgb = mix(vec3(luma(rgb)), rgb, grade.x) * balance; // la lumière colore après la désaturation",
  "    rgb = ((rgb - 0.5) * grade.y + 0.5) * grade.z;",
  "    rgb = mix(clamp(rgb, 0.0, 1.0), voile.rgb, voile.a);",
  "    if (classe == 3.0) rgb = mix(rgb, parcs.rgb * (0.75 + 0.5 * luma(o)), parcs.a); }",
  // 4. Lumières.
  "  if (lumieres == 1) {",
  "    float d = 0.0, h = facade.x / echelle;",
  "    if (toit >= 0.0 && classe == 2.0) for (int i = 1; i <= 48; i++) { float fi = float(i);",
  "      if (fi > h) break; if (bati(px + vec2(0.0, fi)) < 0.5) { d = fi; break; } }",
  "    vec3 k = hsv(o);",
  "    float fac = d > 0.0 ? 1.0 - smoothstep(0.3, 0.5, k.y) * step(k.x, 32.0) : 0.0; // tuiles orangées : toit",
  "    float sol = toit < 0.0 || classe == 1.0 ? 1.0 : facade.w;",
  "    vec3 l = lumiere(px);",
  "    float place = l.b * (classe == 3.0 ? 0.0 : 1.0);",
  // Une surface éclairée montre sa clarté du jour (o) sous la lumière chaude, dont la teinte domine :
  // texture gardée, pas de blanc brûlé ; le cœur, lui, rayonne (mélange écran).
  "    float lr = 1.0 - (1.0 - l.r) * (1.0 - place);",
  "    vec3 teinte = mix(nappeCouleur, placeCouleur, place / max(lr, 0.001));",
  // La lumière chaude chasse le bleu là où elle tombe : sans cela, bleu + orangé passe par le rose.
  "    float w = lr * sol;",
  "    vec3 albedo = mix(vec3(luma(o)), o, fidelite) * eclairage.x;",
  "    rgb = mix(mix(rgb, vec3(luma(rgb)), min(1.0, w * 1.6)), max(rgb, albedo * teinte), w);",
  "    rgb = ecran(rgb, coeurCouleur * l.g * eclairage.y * sol);",
  "    if (fac > 0.0) {",
  "      float t = d / h; vec3 p = lumiere(px + vec2(0.0, d));",
  "      float pied = 1.0 - (1.0 - p.r) * (1.0 - p.g) * (1.0 - p.b);",
  "      float wf = clamp(pied * facade.y * pow(1.0 - t, facade.z) * fac, 0.0, 1.0);",
  "      rgb = mix(mix(rgb, vec3(luma(rgb)), min(1.0, wf * 1.6)), max(rgb, albedo * facadeCouleur), wf);",
  // Fenêtres : cellules fixées au sol ; au niveau 8 une fenêtre dans sa cellule, plus loin un pixel d'écran.
  "      vec2 cel = echelle <= 1.0 ? fenetreForme.xy : vec2(echelle);",
  "      vec2 n = floor(monde / cel), dans = monde - n * cel;",
  "      float remplie = echelle <= 1.0 ? fenetreForme.z * fenetreForme.w / (cel.x * cel.y) : 1.0;",
  "      bool vitre = echelle > 1.0 || (abs(dans.x - cel.x * 0.5) < fenetreForme.z * 0.5 && abs(dans.y - cel.y * 0.5) < fenetreForme.w * 0.5);",
  "      float humeur = 1.0 + (hache(floor(monde / fenetres.y) + 71.3) * 2.0 - 1.0) * fenetres.z;",
  "      if (vitre && t > 0.08 && t < 0.95 && hache(n * 1.37 + 11.1) < fenetres.x * humeur / remplie)",
  "        rgb = mix(rgb, fenetreCouleur, fenetres.w * fac * lumForce * (echelle > 1.0 ? eclairage.z : 1.0)); } }",
  "  gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), c.a); }"
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

const TEXTURES = ["tBase", "tClasse", "tArbres", "tClasseBas", "tLum"]

// UN SEUL contexte WebGL pour toutes les couches d'ambiance ; chaque dalle est calculée ici puis
// recopiée dans son propre canevas 2D.
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
    this.lieux = {}
    this.tex = TEXTURES.map(() => texture(gl))
    this.vide = document.createElement("canvas")
    this.vide.width = this.vide.height = 1
    TEXTURES.forEach((nom, k) => gl.uniform1i(gl.getUniformLocation(p, nom), k))
  }

  u(nom) { return (this.lieux[nom] ??= this.gl.getUniformLocation(this.p, nom)) }

  // images : [base, classe, arbres, classe du dessous, lumière] (null = absente) ; uniformes : { nom: [type, ...valeurs] }.
  traiter(images, uniformes) {
    const gl = this.gl
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    images.forEach((image, k) => {
      gl.activeTexture(gl.TEXTURE0 + k)
      gl.bindTexture(gl.TEXTURE_2D, this.tex[k])
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image || this.vide)
    })
    for (const [nom, [type, ...valeurs]] of Object.entries(uniformes)) gl[`uniform${type}`](this.u(nom), ...valeurs)
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    gl.viewport(0, 0, COTE, COTE)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    return this.toile
  }
}

let moteur = null
const cache = creerCache() // une dalle calculée par état et par chemin, partagé par toutes les ambiances

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

// Couleur (r, g, b) d'un corps noir à `kelvins` (approximation de Tanner Helland), de 0 à 1.
function corpsNoir(kelvins) {
  const t = kelvins / 100
  const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592)
  const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492)
  const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307
  return [r, g, b].map((c) => Math.min(255, Math.max(0, c)) / 255)
}

// Facteurs (r, g, b) de la balance des blancs d'un moment : 6500 K neutre, luminance conservée.
export function balance({ temperature, teinte = 0 }) {
  const ref = corpsNoir(6500), k = corpsNoir(temperature)
  const f = k.map((c, i) => c / ref[i])
  f[0] *= 1 + 0.075 * teinte; f[1] *= 1 - 0.15 * teinte; f[2] *= 1 + 0.075 * teinte
  const l = 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]
  return f.map((c) => c / l)
}

// Les uniformes d'une suite de règles publiées, sous le préfixe `x`.
function uniformesRegles(x, json, dosage = 1) {
  const regles = json?.regles?.slice(0, REGLES_MAX) || []
  const cl = [], ms = [], es = [], mr = [], er = [], fo = []
  for (let i = 0; i < REGLES_MAX; i++) {
    const r = regles[i]
    const v = r ? r.valeurs_classe : []
    cl.push(v.includes(1) ? 1 : 0, v.includes(2) ? 1 : 0, v.includes(3) ? 1 : 0)
    ms.push(...(r ? r.ms : [0, 0, 0])); es.push(...(r ? r.es : [1, 1, 1]))
    mr.push(...(r ? r.mr : [0, 0, 0])); er.push(...(r ? r.er : [1, 1, 1]))
    fo.push(r ? r.force * dosage : 0)
  }
  return {
    [`n${x}`]: ["1i", regles.length], [`${x}Cl`]: ["3fv", cl], [`${x}Ms`]: ["3fv", ms], [`${x}Es`]: ["3fv", es],
    [`${x}Mr`]: ["3fv", mr], [`${x}Er`]: ["3fv", er], [`${x}Force`]: ["1fv", fo]
  }
}

const rgb = (c) => c.map((v) => v / 255)
const hex = (h) => rgb([1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)))

// Les uniformes communes à toutes les dalles d'un état { moment, saison, meteo }. `publies` : les
// étalonnages publiés lus ({ "heure-bleue", hiver, automne } → JSON ou null). null : rien à faire.
export function uniformesEtat(etat, publies, { arbres = false } = {}) {
  const u = {}
  // Saison.
  let saison = 0
  if (etat.saison === "hiver" && publies.hiver) { saison = 1; Object.assign(u, uniformesRegles("s", publies.hiver, PUBLIES.hiver.force)) }
  else if (etat.saison === "automne" && publies.automne) {
    saison = 2
    const feuillage = publies.automne.regles.find((r) => r.valeurs_classe.includes(3)) || publies.automne.regles[0]
    Object.assign(u, uniformesRegles("s", { regles: [feuillage] }))
  } else Object.assign(u, uniformesRegles("s", null))
  u.saison = ["1i", saison]
  const a = AUTOMNE
  u.automne = ["4f", ...[a.intensite, a.variation_teinte_deg * Math.PI / 180, a.variation_clarte, a.taille_arbre_px]]
  u.repli = ["4f", ...[a.repli.teinte_min, a.repli.teinte_max, a.repli.saturation_min, a.repli.valeur_max]]
  u.repliForce = ["1f", a.repli.intensite]
  u.arbresPublies = arbres
  // Météo.
  u.meteo = ["1i", { clair: 0, pluie: 1, neige: 2 }[etat.meteo] ?? 0]
  u.pluie = ["4f", PLUIE.sol_luminosite, PLUIE.sol_contraste, PLUIE.saturation, PLUIE.volumes_luminosite]
  u.pluieVoile = ["1f", PLUIE.assombrissement]
  u.neige = ["4f", NEIGE.toits, NEIGE.sol, 0, 0]
  u.neigeCouleur = ["3fv", rgb(NEIGE.couleur)]
  // Moment.
  let moment = 0
  const m = MOMENTS[etat.moment]
  if (etat.moment === "heure-bleue" && publies["heure-bleue"]) {
    moment = 1
    Object.assign(u, uniformesRegles("m", publies["heure-bleue"], PUBLIES["heure-bleue"].force))
  } else Object.assign(u, uniformesRegles("m", null))
  if (m) moment = 2
  u.moment = ["1i", moment]
  u.balance = ["3fv", m ? balance(m) : [1, 1, 1]]
  u.grade = ["3f", m?.saturation ?? 1, m?.contraste ?? 1, m?.luminosite ?? 1]
  u.voile = ["4f", ...rgb(m?.voile?.couleur ?? [0, 0, 0]), m?.voile?.part ?? 0]
  u.parcs = ["4f", ...rgb(m?.parcs?.couleur ?? [0, 0, 0]), m?.parcs?.part ?? 0]
  // Lumières.
  const lp = LAMPADAIRES, fa = lp.facades, fe = lp.fenetres
  u.lumForce = ["1f", lp.intensite[etat.moment] ?? 0]
  u.debord = ["1f", DEBORD]
  u.nappeCouleur = ["3fv", hex(lp.nappe.couleur)]
  u.coeurCouleur = ["3fv", hex(lp.coeur.couleur)]
  u.placeCouleur = ["3fv", hex(lp.places.couleur)]
  u.gains = ["3f", lp.nappe.gain, lp.coeur.gain, lp.places.gain]
  u.eclairage = ["3f", lp.albedo, lp.coeur.rayonnement, fe.intensite_au_loin]
  u.fidelite = ["1f", lp.fidelite_couleur]
  u.facade = ["4f", fa.hauteur_px, fa.rechauffement, fa.decroissance, lp.sur_toits]
  u.facadeCouleur = ["3fv", hex(fa.couleur)]
  u.fenetres = ["4f", fe.part, fe.grappe_px, fe.ecart_grappes, fe.intensite]
  u.fenetreForme = ["4f", ...fe.cellule_px, ...fe.fenetre_px]
  u.fenetreCouleur = ["3fv", hex(fe.couleur)]
  if (saison === 0 && moment === 0 && u.meteo[1] === 0) return null
  return u
}

// opts : cle (l'état, pour le cache) ; uniformes (Promise, voir uniformesEtat) ;
// dalle / propriete / masque / arbres (chemin → URL) ; estListee, masqueListe, arbresListe
// (coords → booléen) ; moment (nom du moment, pour l'intensité des lampadaires) ; lampadaires
// (Promise de l'index de diorama/lampadaires, ou null) ; options (options de couche Leaflet).
export function creerCoucheAmbiance(L, opts) {
  const force = LAMPADAIRES.intensite[opts.moment] ?? 0
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      const toile = document.createElement("canvas")
      toile.width = toile.height = COTE
      if (!opts.estListee(coords)) {
        setTimeout(() => fini(null, toile), 0)
        return toile
      }
      const chemin = `${coords.z}/${coords.x}/${coords.y}`
      const cle = `${opts.cle}|${chemin}`
      if (cache.lire(cle, toile)) { setTimeout(() => fini(null, toile), 0); return toile }
      opts.uniformes.then((commun) => {
        let urlClasse = null, urlBas = null, mode = 2
        const dessous = { ...coords, y: coords.y + 1 }, cheminBas = `${coords.z}/${coords.x}/${coords.y + 1}`
        if (coords.z === NIVEAU_MAX) {
          urlClasse = opts.propriete(chemin); mode = 0
          if (opts.estListee(dessous)) urlBas = opts.propriete(cheminBas)
        } else if (coords.z >= 6 && opts.masqueListe(coords)) {
          urlClasse = opts.masque(chemin); mode = 1
          if (opts.masqueListe(dessous)) urlBas = opts.masque(cheminBas)
        }
        // Masque des arbres : aux niveaux qu'il couvre (6 à 8), une dalle non listée n'a pas d'arbre.
        const arbres = commun?.saison[1] === 2 && commun.arbresPublies && coords.z >= 6
        return Promise.all([
          commun, charger(opts.dalle(chemin)), charger(urlClasse),
          arbres && opts.arbresListe(coords) ? charger(opts.arbres(chemin)) : null,
          force > 0 ? opts.lampadaires : null,
          force > 0 ? charger(urlBas) : null
        ]).then(([commun, base, classe, imageArbres, lampadaires, classeBas]) => {
          if (!base) { fini(new Error("dalle absente"), toile); return }
          // Pas de willReadFrequently : on ne relit jamais ces pixels, et un canevas 2D gardé sur le GPU
          // reçoit la copie du canevas WebGL sans la faire passer par le processeur.
          const ctx = toile.getContext("2d")
          if (!commun) { ctx.drawImage(base, 0, 0); fini(null, toile); return }
          const echelle = 2 ** (NIVEAU_MAX - coords.z)
          const lumiere = force > 0 ? carteDeLumiere(coords, lampadaires) : null
          const uniformes = { ...commun,
            modeClasse: ["1i", classe ? mode : 2],
            lumieres: ["1i", lumiere ? 1 : 0],
            classeBas: ["1i", classe && classeBas ? 1 : 0],
            origine: ["2f", coords.x * COTE * echelle, coords.y * COTE * echelle],
            echelle: ["1f", echelle],
            modeArbres: ["1i", arbres ? 1 : 0]
          }
          delete uniformes.arbresPublies
          moteur ||= new Moteur()
          ctx.drawImage(moteur.traiter([base, classe, imageArbres, classeBas, lumiere], uniformes), 0, 0)
          dessinerFeux(ctx, coords, lampadaires, force)
          cache.garder(cle, toile)
          fini(null, toile)
        })
      }).catch((erreur) => fini(erreur, toile))
      return toile
    }
  })
  return comblerInterstices(new Couche(opts.options))
}
