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
// 1 sol, 2 volume, 3 feuillage. La classe vient de la carte de propriété au niveau 8 (agrandie au-delà), du
// masque du bâti aux niveaux 6-7, et ailleurs tout pixel non transparent est un volume.
//
// L'automne n'applique la règle « feuillage » de son étalonnage qu'aux pixels du masque des arbres
// (masque-arbres, niveaux 6 à 8) ; sans ce masque, aux verts sombres (repli). Chaque arbre prend
// ensuite sa propre teinte, du jaune au roux : une cellule de Voronoï de la taille d'un houppier,
// calée sur les pixels du niveau 8, donc fixe au sol quel que soit le zoom ou le déplacement.
import { COTE, creerCache, comblerInterstices, NIVEAU_ANNEXES, versAnnexe, chargerAnnexe } from "diorama/couches"
import { carteDeLumiere, dessinerFeux, DEBORD } from "diorama/lampadaires"
import { MOMENTS, PUBLIES, AUTOMNE, PLUIE, NEIGE, LAMPADAIRES, NUIT_CIBLES, VUE } from "diorama/reglages"
import { haloMode } from "diorama/vue"

const REGLES_MAX = 3 // par étalonnage publié (hiver : 2, heure bleue et automne : 1)
const NIVEAU_REPERE = 8
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
  "uniform sampler2D tBase, tClasse, tArbres, tClasseBas, tLum, tClasseHaut, tBat;",
  // nuit-chaude-v1 : classe de la dalle du DESSUS (ombre de contact : on cherche la façade au-dessus du sol, et près
  // du bord haut elle est chez la voisine) ; bâtiment par pixel (tirage des fenêtres par bâtiment) ; sortie 1 = la
  // seule ÉMISSION (fenêtres allumées, cœurs des lampadaires), que la vue floute en halo.
  "uniform int classeHaut, batiments, sortie;",
  "uniform vec4 contact;     // portée au pied (px n8), décroissance (px n8), force au pied, force en rue resserrée",
  "uniform float contactRue; // largeur (px n8) sous laquelle une rue compte pour resserrée",
  "uniform vec4 parBatiment; // part mini, part maxi, exposant du tirage, part des bâtiments tout éteints",
  "uniform float emissionLampes; // part du cœur des lampadaires versée à l'émission",
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
  "uniform float voileOmbres; // 1 : voile réservé aux zones sombres (nuit v7), 0 : mélange plat (autres moments)",
  "uniform vec4 parcs;       // couleur des parcs la nuit, et sa part",
  "uniform int lumieres;     // 1 : carte de lumière (tLum, COTE × (COTE + debord)) à poser",
  "uniform int classeBas;    // 1 : classe de la dalle du dessous lue (tClasseBas)",
  "uniform float lumForce, debord;",
  "uniform vec3 coeurCouleur, gains;",
  "uniform vec3 eclairage;   // (inutilisé), part du cœur, fenêtres au loin",
  "uniform vec4 facade;      // hauteur (px du niveau 8), réchauffement, décroissance, part reçue par les toits",
  "uniform vec3 fenetreCouleur;",
  "uniform vec4 fenetres;    // part, taille de grappe (px du niveau 8), écart entre grappes, intensité",
  "uniform vec4 fenetreForme; // cellule (l, h), fenêtre (l, h), en px du niveau 8",
  "uniform int fenetresPeintes; // 1 : la dalle porte ses fenêtres peintes (jeu-video-v2) : on allume celles-là",
  "uniform float vitreContraste; // écart de clarté minimal d'une vitre peinte avec son mur, de part et d'autre",
  "uniform vec4 zoneGare;    // segment (x0, y0, x1, y1) en px du niveau 8, sans fenêtres (quais)",
  "uniform float zoneGareRayon; // demi-largeur du couloir, en px du niveau 8 ; <= 0 : désactivé",
  // v7b : couleurs cibles mesurées (médianes HSV) sur la référence, en RGB 0-1 ; converties en Lab dans
  // ce shader (versLab) pour teinter en a*/b* les rues, façades et ombres SANS passer par un mélange RGB
  // « max »/« écran » qui blanchissait les zones de recouvrement (voir NUIT_CIBLES, diorama/reglages).
  "uniform vec3 cibleRue, cibleFacade, cibleOmbre;",
  "uniform float doseRue, doseFacade; // dosage de la teinte (a*/b*) vers la cible (1 = plein à w ou wf = 1)",
  // v7b (correctif place/gare) : la clarté (L*) ne se mélange plus vers la cible (ça écrasait toute
  // variation locale — pavés, ombres portées — dès que w approchait 1, d'où l'aplat plat sur la place
  // Stanislas et le coin saturé de la gare) ; elle reçoit un LIFT ADDITIF plafonné à la cible, en L*
  // (voir plus bas) : la texture reste visible tant qu'elle ne dépasse pas le plafond.
  "uniform float gainRue, gainFacade;",
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
  // v7c (ombre) : rotation de teinte a*/b* qui CONSERVE LE CHROMA DU PIXEL D'ORIGINE — contrairement à un
  // mix qui dérive vers le chroma de la cible (ici très faible : cibleOmbre est mesurée quasi noire), ce
  // qui désature les ombres bien plus que la référence. On tourne donc l'angle seul, à l'arc le plus court
  // SAUF quand celui-ci traverse le vert/cyan (~140°-215° en angle Lab — le point médian du trajet suffit
  // à le détecter) : l'or et le crème des façades jour (~85°-95°) sont juste de l'autre côté de cette
  // zone que le bleu-violet des ombres (~245°-260°), donc l'arc le plus court y passe presque toujours ;
  // on force alors le grand tour, par le rouge/magenta, sans effet visible car aucune des deux couleurs
  // n'est proche de cette zone. rO quasi nul (gris neutre) : retour à un mix brut, sûr (pas d'angle instable).
  "vec2 giroYZ(vec2 origine, vec2 cible, float t){",
  "  float rO = length(origine);",
  "  if (rO < 0.0008) return mix(origine, cible, t);",
  "  float aO = atan(origine.y, origine.x), aC = atan(cible.y, cible.x);",
  "  float diff = mod(aC - aO + 3.14159265, 6.28318531) - 3.14159265;",
  "  float mid = mod(aO + diff * 0.5 + 6.28318531, 6.28318531);",
  "  if (mid > 2.44346 && mid < 3.75246) diff -= sign(diff) * 6.28318531;",
  "  return rO * vec2(cos(aO + diff * t), sin(aO + diff * t));",
  "}",
  "vec3 hsv(vec3 c){ float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn, h = 0.0;",
  "  if (d > 0.0) { if (mx == c.r) h = 60.0 * (c.g - c.b) / d; else if (mx == c.g) h = 120.0 + 60.0 * (c.b - c.r) / d;",
  "    else h = 240.0 + 60.0 * (c.r - c.g) / d; if (h < 0.0) h += 360.0; }",
  "  return vec3(h, mx > 0.0 ? d / mx : 0.0, mx); }",
  "bool feuillage(vec3 c){ vec3 k = hsv(c); return k.y > 0.12 && k.x >= 60.0 && k.x <= 130.0; }",
  // Houppier (automne seulement) : vert de 79° à 130°. Les pelouses de jeu-video-v2, vert-jaune (73-78°),
  // restent dehors : le masque des arbres, calé sur toits-v1, déborde dessus (plaques d'automne). Les
  // houppiers sont plus bleutés (80-99° sur jeu-video-v2, 81-120° sur toits-v1, gardés à 96 %). Pas dans
  // feuillage() : la classe 3 qu'il donne règle aussi l'hiver, où les pelouses sorties viraient au jaune.
  "bool houppier(vec3 c){ return feuillage(c) && hsv(c).x >= 79.0; }",
  // Eau (26/10) : la carte de propriété n'a pas de classe « eau », le canal et la Meurthe y sont du sol ; la nuit, la
  // lumière des rues et des places (or) et le voile des ombres (brun) les doraient près des quais. Bleu-cyan saturé
  // d'origine : 184-200°, saturation 0,46-0,72, valeur 0,71-0,85 mesurées sur jeu-video-v2 (port Sainte-Catherine).
  "float eau(vec3 c){ vec3 k = hsv(c); return smoothstep(172.0, 182.0, k.x) * (1.0 - smoothstep(212.0, 222.0, k.x)) *",
  "  smoothstep(0.30, 0.42, k.y) * smoothstep(0.35, 0.50, k.z); }",
  "float luma(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }",
  // Vitre peinte : un pixel nettement plus sombre que le mur tout autour (à 2 px, sur les quatre côtés :
  // une fenêtre est un petit rectangle sombre sur une façade claire). Ni un pan de toit uni ni un trait
  // d'égout ne l'est : plus de fenêtres sur les toits, ni sur le sol mal calé par les masques.
  "float clarteA(vec2 p){ return luma(texture2D(tBase, vec2(p.x / 256.0, 1.0 - p.y / 256.0)).rgb); }",
  // nuit-chaude-v1 : l'écart au mur (2 px au niveau 8) suit le niveau — au niveau 9 la vitre fait le double, et le
  // voisin à 2 px tombait encore dans la vitre (793 vitres reconnues sur 138 802 px de façade du pilote).
  "uniform float vitreEcart; // px du niveau 8",
  "uniform float vitreCotes; // côtés plus clairs exigés autour d'une vitre",
  "bool vitrePeinte(vec2 px, float l){ vec2 c = floor(px) + 0.5; float k = floor(vitreEcart / echelle + 0.5);",
  "  float g = clarteA(c - vec2(k, 0.0)), d = clarteA(c + vec2(k, 0.0)), h = clarteA(c - vec2(0.0, k)), b = clarteA(c + vec2(0.0, k));",
  // nuit-chaude-v1 : TROIS côtés sur quatre suffisent (?vitre-cotes=4 rend le test d'avant) — une vitre contre un
  // trumeau sombre, un volet ou le bord de la façade gardait sa vitre éteinte.
  "  float n = step(vitreContraste, g - l) + step(vitreContraste, d - l) + step(vitreContraste, h - l) + step(vitreContraste, b - l);",
  "  return n >= vitreCotes - 0.5; }",
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
  "float bati(vec2 p){ bool bas = p.y >= 256.0, haut = p.y < 0.0;",
  "  if (bas) { if (classeBas == 0) return 0.0; p.y -= 256.0; }",
  "  if (haut) { if (classeHaut == 0) return 0.0; p.y += 256.0; }",
  "  if (p.x < 0.0 || p.x >= 256.0) return 0.0;",
  "  vec2 q = vec2((floor(p.x) + 0.5) / 256.0, 1.0 - (floor(p.y) + 0.5) / 256.0);",
  "  float r = bas ? texture2D(tClasseBas, q).r : (haut ? texture2D(tClasseHaut, q).r : texture2D(tClasse, q).r);",
  "  if (modeClasse == 0) { float k = floor(r * 255.0 + 0.5); return (k == 2.0 || k == 4.0) ? 1.0 : 0.0; }",
  "  return r > 0.5 ? 1.0 : 0.0; }",
  // La lumière reçue en `p`, saturée en douceur ; `lumForce` (40 % à l'heure bleue) dose l'énergie, pas le
  // mélange : moins de portée, mais une lumière toujours dorée là où elle tombe.
  "vec3 lumiere(vec2 p){ vec3 l = texture2D(tLum, vec2(p.x / 256.0, 1.0 - p.y / (256.0 + debord))).rgb;",
  "  return 1.0 - exp(-gains * l * lumForce); }",
  "vec3 ecran(vec3 a, vec3 b){ return 1.0 - (1.0 - a) * (1.0 - clamp(b, 0.0, 1.0)); }",
  "float distSeg(vec2 p, vec2 a, vec2 b){ vec2 pa = p - a, ba = b - a;",
  "  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }",
  reglesGLSL("s"),
  reglesGLSL("m"),
  "void main(){",
  "  vec4 c = texture2D(tBase, uv);",
  "  if (c.a < 0.5) { gl_FragColor = c; return; }",
  "  vec3 o = c.rgb;",
  "  vec3 em = vec3(0.0); // nuit-chaude-v1 : émission (fenêtres, cœurs), sortie 1",
  "  vec3 dbg = vec3(0.0); // sortie 2 (diagnostic) : r façade reconnue, g vitre peinte reconnue, b vitre allumée",
  "  vec2 px = vec2(uv.x, 1.0 - uv.y) * 256.0;       // pixel de la dalle (y vers le bas)",
  "  vec2 monde = origine + px * echelle;            // pixel du niveau 8",
  // Classe du pixel, et part de toit (neige).
  "  float classe, toit;",
  "  if (modeClasse == 0) { float k = floor(texture2D(tClasse, uv).r * 255.0 + 0.5);",
  "    classe = (k == 1.0 || k == 3.0) ? 1.0 : ((k == 2.0 || k == 4.0) ? 2.0 : 0.0); toit = classe == 2.0 ? 1.0 : 0.0; }",
  "  else if (modeClasse == 1) { toit = texture2D(tClasse, uv).r; classe = toit > 0.5 ? 2.0 : 1.0; }",
  "  else { classe = 2.0; toit = -1.0; }",
  "  if (classe > 0.0 && feuillage(o)) classe = 3.0;",
  "  float eauW = classe < 1.5 ? eau(o) : 0.0; // l'eau garde son bleu : ni or des lumières, ni brun du voile",
  // Poids de la lumière des rues/places au pied de CE pixel, calculé ICI (avant l'ombre) et réutilisé
  // tel quel plus bas (étape 4) : sans cela, l'ombre teinte vers le bleu-violet un pixel qui va de toute
  // façon recevoir la lumière chaude juste après, et les deux rotations de teinte opposées se composent
  // en travers du cercle des teintes — visible comme une frange cyan/magenta aux bords des halos (v7b).
  "  vec3 lLum = vec3(0.0); float wLum = 0.0;",
  "  if (lumieres == 1) { lLum = lumiere(px);",
  "    float solPre = toit < 0.0 || classe == 1.0 ? 1.0 : facade.w;",
  "    float placePre = lLum.b * (classe == 3.0 ? 0.0 : 1.0);",
  "    wLum = (1.0 - (1.0 - lLum.r) * (1.0 - placePre)) * solPre * (1.0 - eauW); }",
  "  vec3 lab = versLab(o);",
  // 1. Saison.
  "  if (saison == 1) lab = regles_s(lab, classe);",
  "  else if (saison == 2) {",
  // Le masque des arbres est calculé sur le rendu de toits-v1 : sur un autre style (jeu-video-v2), ses
  // houppiers tombent aussi sur des toits, des façades ou la chaussée. Seul le feuillage prend la teinte.
  "    float w = (modeArbres == 1 ? texture2D(tArbres, uv).r * (houppier(o) ? 1.0 : 0.0) : verts_sombres(o) * repliForce) * automne.x;",
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
  "    rgb = clamp(rgb, 0.0, 1.0);",
  // Voile réservé aux ombres (nuit v7) : les surfaces déjà claires (rues, façades, toits) le traversent
  // presque sans le voir ; seules les zones sombres/non éclairées virent vers la teinte mesurée
  // (cibleOmbre). v7b : ce virage ne touche que a*/b* (Lab), jamais L* — donc aucun assombrissement
  // supplémentaire au-delà de celui déjà posé par `luminosite` ci-dessus.
  "    if (voileOmbres > 0.5) {",
  "      float part = voile.a * (1.0 - smoothstep(0.05, 0.30, luma(rgb))) * (1.0 - clamp(wLum, 0.0, 1.0)) * (1.0 - eauW);",
  "      vec3 labV = versLab(rgb), cibleV = versLab(cibleOmbre);",
  // giroYZ (voir sa définition) : rotation à chroma conservé, grand tour forcé par le rouge/magenta pour
  // ne jamais traverser le vert/cyan — remplace le mix brut v7c, qui évitait bien la frange mais désaturait
  // les ombres bien en dessous de la cible mesurée (cibleOmbre est mesurée quasi noire, donc peu chromatique).
  "      labV.yz = giroYZ(labV.yz, cibleV.yz, part);",
  "      rgb = depuisLab(labV);",
  "    } else {",
  "      rgb = mix(rgb, voile.rgb, voile.a);",
  "    }",
  "    if (classe == 3.0) rgb = mix(rgb, parcs.rgb * (0.75 + 0.5 * luma(o)), parcs.a); }",
  // 4. Lumières.
  "  if (lumieres == 1) {",
  "    float d = 0.0, h = facade.x / echelle;",
  // v7b : recherche du sol approfondie (72 pas, au lieu de 48) pour que `hauteur_px` puisse couvrir des
  // immeubles plus hauts sans être plafonnée par la boucle elle-même.
  "    if (toit >= 0.0 && classe == 2.0) for (int i = 1; i <= 72; i++) { float fi = float(i);",
  "      if (fi > h) break; if (bati(px + vec2(0.0, fi)) < 0.5) { d = fi; break; } }",
  "    vec3 k = hsv(o);",
  "    bool tuile = k.y > 0.3 && k.x <= 32.0, ardoise = k.x >= 175.0 && k.x <= 260.0 && k.y < 0.35;",
  "    float fac = d > 0.0 && !tuile && !ardoise ? 1.0 : 0.0; // tuiles orangées et ardoises bleues : toit, pas de fenêtres",
  "    dbg.r = fac;",
  "    float sol = toit < 0.0 || classe == 1.0 ? 1.0 : facade.w;",
  // l, w : déjà calculés plus haut (lLum, wLum), avant l'ombre — voir le commentaire à leur déclaration.
  "    vec3 l = lLum; float w = wLum;",
  // v7b : la surface éclairée se déplace en Lab vers la couleur cible mesurée (cibleRue). a*/b* : mix
  // direct des vecteurs (pas giroYZ ici — la cible est déjà bien chromatique, un mix brut ne désature
  // pas de façon sensible, et ça évite une rotation inutile sur des pixels déjà proches de l'or).
  // L* : LIFT ADDITIF plafonné à la cible (jamais au-delà, donc jamais de blanc), pas un mix — un mix
  // écrase toute variation locale (pavés, ombres portées) dès que w approche 1 sur une large zone
  // (place, carrefour) ; l'addition plafonnée garde cette texture tant qu'elle ne dépasse pas le plafond.
  "    if (w > 0.0) {",
  "      vec3 labR = versLab(rgb), cibleR = versLab(cibleRue);",
  "      float wTeinte = clamp(w * doseRue, 0.0, 1.0);",
  "      labR.yz = mix(labR.yz, cibleR.yz, wTeinte);",
  "      labR.x = min(labR.x + gainRue * w, cibleR.x);",
  "      rgb = depuisLab(labR);",
  "    }",
  "    rgb = ecran(rgb, coeurCouleur * l.g * eclairage.y * sol);",
  "    em = max(em, coeurCouleur * l.g * emissionLampes * sol);",
  "    if (fac > 0.0) {",
  "      float t = d / h; vec3 p = lumiere(px + vec2(0.0, d));",
  "      float pied = 1.0 - (1.0 - p.r) * (1.0 - p.g) * (1.0 - p.b);",
  "      float wf = clamp(pied * facade.y * pow(1.0 - t, facade.z) * fac, 0.0, 1.0);",
  "      if (wf > 0.0) {",
  "        vec3 labF = versLab(rgb), cibleF = versLab(cibleFacade);",
  "        float wTeinteF = clamp(wf * doseFacade, 0.0, 1.0);",
  "        labF.yz = mix(labF.yz, cibleF.yz, wTeinteF);",
  "        labF.x = min(labF.x + gainFacade * wf, cibleF.x);",
  "        rgb = depuisLab(labF);",
  "      }",
  // Fenêtres : cellules fixées au sol ; au niveau 8 une fenêtre dans sa cellule, plus loin un pixel d'écran.
  "      if (fenetresPeintes == 1) {",
  // Une vitre peinte, allumée ou non selon sa cellule au sol (stable d'un chargement à l'autre).
  "        vec2 n = floor(monde / fenetreForme.xy);",
  "        float humeur = 1.0 + (hache(floor(monde / fenetres.y) + 71.3) * 2.0 - 1.0) * fenetres.z;",
  // nuit-chaude-v1 : là où le bâtiment est connu (tBat), sa part allumée est TIRÉE une fois pour lui, de sa
  // couleur d'identifiant : une part `parBatiment.w` des bâtiments est tout éteinte, les autres tirent leur part
  // entre parBatiment.x et .y (u^exposant, qui penche vers les parts basses). Sinon, l'humeur de grappe d'avant.
  "        float seuil = 3.0 * fenetres.x * humeur;",
  "        vec3 idb = batiments == 1 ? texture2D(tBat, uv).rgb : vec3(0.0);",
  "        if (dot(idb, vec3(1.0)) > 0.0) { float u1 = hache(idb.rg * 255.0 + idb.b * 17.0), u2 = hache(idb.gb * 255.0 + 3.7);",
  "          seuil = u2 < parBatiment.w ? 0.0 : mix(parBatiment.x, parBatiment.y, pow(u1, parBatiment.z)); }",
  // nuit-chaude-v1 : comme la grille procédurale, ni le pied (portes, vitrines) ni le haut (égout, corniche, où le
  // test à trois côtés prend des traits sombres pour des vitres) de la façade.
  "        bool vit = t > 0.06 && t < 0.92 && vitrePeinte(px, luma(o));",
  "        if (vit) dbg.g = 1.0;",
  "        if (vit && hache(n * 1.37 + 11.1) < seuil) { dbg.b = 1.0;",
  "          float a = fenetres.w * fac * lumForce;",
  "          rgb = mix(rgb, fenetreCouleur, a); em = max(em, fenetreCouleur * a); }",
  "      } else {",
  "      vec2 cel = echelle <= 1.0 ? fenetreForme.xy : vec2(echelle);",
  "      vec2 n = floor(monde / cel), dans = monde - n * cel;",
  "      float remplie = echelle <= 1.0 ? fenetreForme.z * fenetreForme.w / (cel.x * cel.y) : 1.0;",
  "      bool vitre = echelle > 1.0 || (abs(dans.x - cel.x * 0.5) < fenetreForme.z * 0.5 && abs(dans.y - cel.y * 0.5) < fenetreForme.w * 0.5);",
  "      float humeur = 1.0 + (hache(floor(monde / fenetres.y) + 71.3) * 2.0 - 1.0) * fenetres.z;",
  "      bool horsGare = zoneGareRayon <= 0.0 || distSeg(monde, zoneGare.xy, zoneGare.zw) > zoneGareRayon;",
  "      if (vitre && horsGare && t > 0.08 && t < 0.95 && hache(n * 1.37 + 11.1) < fenetres.x * humeur / remplie)",
  "        rgb = mix(rgb, fenetreCouleur, fenetres.w * fac * lumForce * (echelle > 1.0 ? eclairage.z : 1.0)); } } }",
  // nuit-chaude-v1 — 5. Ombre de contact, sur le sol seul. On remonte à l'écran depuis le pixel de sol jusqu'au
  // premier pixel bâti (la façade dont c'est le pied) : assombrissement en exp(−d / décroissance). Si le bâti est
  // AUSSI proche en dessous (le dos de l'îlot d'en face) et que la somme passe sous `contactRue`, la rue est
  // resserrée : assombrissement de plus. Distances en px du niveau 8, ramenées à la dalle par `echelle`.
  "  if (contact.z + contact.w > 0.0 && classe == 1.0 && toit >= 0.0) {",
  "    float portee = contact.x / echelle, dh = 0.0, db = 0.0;",
  "    for (int i = 1; i <= 48; i++) { float fi = float(i); if (fi > portee) break;",
  "      if (dh == 0.0 && bati(px - vec2(0.0, fi)) > 0.5) dh = fi;",
  "      if (db == 0.0 && bati(px + vec2(0.0, fi)) > 0.5) db = fi;",
  "      if (dh > 0.0 && db > 0.0) break; }",
  "    float pied = dh > 0.0 ? exp(-(dh - 1.0) * echelle / contact.y) : 0.0;",
  "    float rue = dh > 0.0 && db > 0.0 ? 1.0 - smoothstep(0.5 * contactRue, contactRue, (dh + db) * echelle) : 0.0;",
  "    rgb *= 1.0 - clamp(contact.z * pied + contact.w * rue, 0.0, 0.9); }",
  "  if (sortie == 1) { gl_FragColor = vec4(clamp(em, 0.0, 1.0), c.a); return; }",
  "  if (sortie == 2) { gl_FragColor = vec4(dbg, c.a); return; }",
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

const TEXTURES = ["tBase", "tClasse", "tArbres", "tClasseBas", "tLum", "tClasseHaut", "tBat"]

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
// nuit-chaude-v1 : le canevas d'ÉMISSION de chaque dalle calculée, par la même clé que le cache, que la couche de halo
// (creerCoucheEmission) attend. Une entrée se résout une fois, à null si la dalle n'a pas d'émission.
const emissions = new Map()
function emission(cle) {
  let e = emissions.get(cle)
  if (!e) {
    let ok
    e = { promesse: new Promise((r) => { ok = r }), ok }
    emissions.set(cle, e)
    if (emissions.size > 600) emissions.delete(emissions.keys().next().value)
  }
  return e
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
export function uniformesEtat(etat, publies, { arbres = false, projection = null } = {}) {
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
  u.voileOmbres = ["1f", m?.voile?.ombres ? 1 : 0]
  u.parcs = ["4f", ...rgb(m?.parcs?.couleur ?? [0, 0, 0]), m?.parcs?.part ?? 0]
  // Lumières.
  const lp = LAMPADAIRES, fa = lp.facades, fe = lp.fenetres
  u.lumForce = ["1f", lp.intensite[etat.moment] ?? 0]
  u.debord = ["1f", DEBORD]
  u.coeurCouleur = ["3fv", hex(lp.coeur.couleur)]
  u.gains = ["3f", lp.nappe.gain, lp.coeur.gain, lp.places.gain]
  u.eclairage = ["3f", 0, lp.coeur.rayonnement, fe.intensite_au_loin]
  u.facade = ["4f", fa.hauteur_px, fa.rechauffement, fa.decroissance, lp.sur_toits]
  u.fenetres = ["4f", fe.part, fe.grappe_px, fe.ecart_grappes, fe.intensite]
  u.fenetreForme = ["4f", ...fe.cellule_px, ...fe.fenetre_px]
  u.fenetreCouleur = ["3fv", hex(fe.couleur)]
  u.vitreContraste = ["1f", fe.vitre_contraste]
  u.vitreEcart = ["1f", fe.vitre_ecart_px ?? 2]
  u.vitreCotes = ["1f", fe.vitre_cotes ?? 4]
  u.cibleRue = ["3fv", rgb(NUIT_CIBLES.rue)]
  u.cibleFacade = ["3fv", rgb(NUIT_CIBLES.facade)]
  u.cibleOmbre = ["3fv", rgb(NUIT_CIBLES.ombre)]
  u.doseRue = ["1f", lp.nappe.doseTeinte ?? 1]
  u.doseFacade = ["1f", fa.doseTeinte ?? 1]
  u.gainRue = ["1f", lp.nappe.gainL ?? 40]
  u.gainFacade = ["1f", fa.gainL ?? 32]
  const c = lp.contact, pb = fe.par_batiment
  u.contact = ["4f", c.portee_px, c.decroissance_px, c.pied, c.rue]
  u.contactRue = ["1f", c.rue_px]
  u.parBatiment = ["4f", pb.part_min, pb.part_max, pb.exposant, pb.eteints]
  u.emissionLampes = ["1f", lp.coeur.emission]
  const zg = LAMPADAIRES.zone_sans_fenetres
  if (projection && zg) {
    const [x0, y0] = projection.pixel(zg.a.lat, zg.a.lon)
    const [x1, y1] = projection.pixel(zg.b.lat, zg.b.lon)
    u.zoneGare = ["4f", x0, y0, x1, y1]
    u.zoneGareRayon = ["1f", zg.demi_largeur_m * lp.sol_m_px]
  } else {
    u.zoneGare = ["4f", 0, 0, 0, 0]
    u.zoneGareRayon = ["1f", 0]
  }
  if (saison === 0 && moment === 0 && u.meteo[1] === 0) return null
  return u
}

// opts : cle (l'état, pour le cache) ; uniformes (Promise, voir uniformesEtat) ;
// dalle (coords → URL, le style actif ou son repli) ; propriete / masque / arbres (chemin → URL) ;
// estCouverte, masqueListe, arbresListe, fenetresPeintes (coords → booléen) ; moment (nom du moment, pour
// l'intensité des lampadaires) ; lampadaires (Promise de l'index de diorama/lampadaires, ou null) ;
// options (options de couche Leaflet).
export function creerCoucheAmbiance(L, opts) {
  const force = LAMPADAIRES.intensite[opts.moment] ?? 0
  const halo = haloMode()
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      const toile = document.createElement("canvas")
      toile.width = toile.height = COTE
      if (!opts.estCouverte(coords)) {
        setTimeout(() => fini(null, toile), 0)
        return toile
      }
      const chemin = `${coords.z}/${coords.x}/${coords.y}`
      const cle = `${opts.cle}|${chemin}`
      const gardee = cache.lire(cle, toile)
      if (gardee) { emission(cle).ok(gardee.emission ?? null); setTimeout(() => fini(null, toile), 0); return toile }
      opts.uniformes.then((commun) => {
        let urlClasse = null, urlBas = null, mode = 2
        // Au-delà du niveau 8, propriété et masques viennent de la dalle d'origine, agrandie (versAnnexe).
        const dessous = { ...coords, y: coords.y + 1 }, dessus = { ...coords, y: coords.y - 1 }
        const annexe = versAnnexe(coords), annexeBas = versAnnexe(dessous), annexeHaut = versAnnexe(dessus)
        let urlHaut = null
        if (coords.z >= NIVEAU_ANNEXES) {
          urlClasse = opts.propriete(annexe.chemin); mode = 0
          if (opts.estCouverte(dessous)) urlBas = opts.propriete(annexeBas.chemin)
          if (opts.estCouverte(dessus)) urlHaut = opts.propriete(annexeHaut.chemin)
        } else if (coords.z >= 6 && opts.masqueListe(annexe)) {
          urlClasse = opts.masque(annexe.chemin); mode = 1
          if (opts.masqueListe(annexeBas)) urlBas = opts.masque(annexeBas.chemin)
        }
        // Masque des arbres : aux niveaux qu'il couvre (6 à 8, agrandi au-delà), une dalle non couverte n'a pas d'arbre.
        const arbres = commun?.saison[1] === 2 && commun.arbresPublies && coords.z >= 6
        return Promise.all([
          commun, charger(opts.dalle(coords)), chargerAnnexe(urlClasse, annexe),
          arbres && opts.arbresListe(annexe) ? chargerAnnexe(opts.arbres(annexe.chemin), annexe) : null,
          force > 0 ? opts.lampadaires : null,
          force > 0 ? chargerAnnexe(urlBas, annexeBas) : null,
          force > 0 ? chargerAnnexe(urlHaut, annexeHaut) : null,
          force > 0 && opts.batiments && coords.z >= NIVEAU_ANNEXES ? chargerAnnexe(opts.batiments(annexe.chemin), annexe) : null
        ]).then(([commun, base, classe, imageArbres, lampadaires, classeBas, classeHaut, bat]) => {
          if (!base) { emission(cle).ok(null); fini(new Error("dalle absente"), toile); return }
          // Pas de willReadFrequently : on ne relit jamais ces pixels, et un canevas 2D gardé sur le GPU
          // reçoit la copie du canevas WebGL sans la faire passer par le processeur.
          const ctx = toile.getContext("2d")
          if (!commun) { ctx.drawImage(base, 0, 0); emission(cle).ok(null); fini(null, toile); return }
          const echelle = 2 ** (NIVEAU_REPERE - coords.z)
          const lumiere = force > 0 ? carteDeLumiere(coords, lampadaires) : null
          const uniformes = { ...commun,
            modeClasse: ["1i", classe ? mode : 2],
            lumieres: ["1i", lumiere ? 1 : 0],
            classeBas: ["1i", classe && classeBas ? 1 : 0],
            classeHaut: ["1i", classe && classeHaut ? 1 : 0],
            batiments: ["1i", bat ? 1 : 0],
            sortie: ["1i", 0],
            origine: ["2f", coords.x * COTE * echelle, coords.y * COTE * echelle],
            echelle: ["1f", echelle],
            modeArbres: ["1i", arbres ? 1 : 0],
            fenetresPeintes: ["1i", opts.fenetresPeintes?.(coords) ? 1 : 0]
          }
          delete uniformes.arbresPublies
          moteur ||= new Moteur()
          const images = [base, classe, imageArbres, classeBas, lumiere, classeHaut, bat]
          // nuit-chaude-v1 : l'émission d'abord (même programme, sortie 1), dans son propre canevas ; la vue la floute.
          if (force > 0 && halo) {
            const e = document.createElement("canvas")
            e.width = e.height = COTE
            const ce = e.getContext("2d")
            const diag = typeof location !== "undefined" && new URLSearchParams(location.search).get("diagnostic") === "1"
            ce.drawImage(moteur.traiter(images, { ...uniformes, sortie: ["1i", diag ? 2 : 1] }), 0, 0)
            dessinerFeux(ce, coords, lampadaires, force, true)
            toile.emission = e
          }
          emission(cle).ok(toile.emission ?? null)
          ctx.drawImage(moteur.traiter(images, uniformes), 0, 0)
          dessinerFeux(ctx, coords, lampadaires, force)
          // Halo « dalle » : le flou et le gain du volet, appliqués une fois à la création, sans volet filtré. Le flou
          // ne voit pas l'émission des voisines : un halo s'arrête au bord de la dalle (σ 3 px, donc ~9 px).
          if (toile.emission && halo === "dalle") {
            ctx.save()
            ctx.filter = `blur(${VUE.halo.sigma_px}px) brightness(${VUE.halo.gain})`
            ctx.globalCompositeOperation = "screen"
            ctx.drawImage(toile.emission, 0, 0)
            ctx.restore()
            window.__haloDalles = (window.__haloDalles ?? 0) + 1 // témoin du banc : dalles qui ont reçu leur halo
          }
          cache.garder(cle, toile)
          fini(null, toile)
        })
      }).catch((erreur) => { emission(cle).ok(null); fini(erreur, toile) })
      return toile
    }
  })
  const couche = comblerInterstices(new Couche(opts.options))
  // nuit-chaude-v1 : aux moments éclairés, la couche de halo qui l'accompagne (à poser dans le volet « halo », vue.js).
  if (force > 0 && halo === "vue") couche.emission = creerCoucheEmission(L, opts)
  return couche
}

// La couche d'ÉMISSION d'une couche d'ambiance : chaque dalle recopie le canevas d'émission que la dalle d'ambiance
// de même clé a calculé (rien n'est calculé ici). Le flou et le gain du halo sont ceux du VOLET (vue.js) : ils
// portent sur la vue entière et ne connaissent donc pas les bords de dalle.
function creerCoucheEmission(L, opts) {
  const Couche = L.GridLayer.extend({
    createTile(coords, fini) {
      const toile = document.createElement("canvas")
      toile.width = toile.height = COTE
      if (!opts.estCouverte(coords)) { setTimeout(() => fini(null, toile), 0); return toile }
      emission(`${opts.cle}|${coords.z}/${coords.x}/${coords.y}`).promesse.then((e) => {
        if (e) toile.getContext("2d").drawImage(e, 0, 0)
        fini(null, toile)
      })
      return toile
    }
  })
  return comblerInterstices(new Couche({ ...opts.options, pane: "halo", attribution: null }))
}
