#!/usr/bin/env python3
"""Sprites des OCCUPATIONS SAISONNIÈRES des places (config/diorama/occupations_places.yml), dans le style « jeu vidéo ».

Tous sont rendus avec LA caméra et LE soleil du diorama (nancy-3d, jeu-video-v2 v18) : projection orthographique, matrice A
en px du niveau 8 par mètre Lambert-93 (vérifiée sur reference_de_pose du manifeste : azimut 200°, compression 0,643,
facteur de hauteur 0,766, 2,2626 px/m), soleil azimut 140°, hauteur 45°, cuit dans l'image (jamais de miroir).

  sapin      RÉUTILISÉ : le gabarit « conifère » de la bibliothèque d'arbres v18 (nancy-3d), cuit par sa propre fonction
             `cuire`, mis aux dimensions du sapin 2026 ; on y ajoute une guirlande (ampoules visibles seulement là où la
             spirale passe devant le feuillage) et une étoile. Exige le dépôt nancy-3d (NANCY3D, défaut ~/Documents/nancy-3d).
  roue, patinoire, chalets : CRÉÉS ici, géométrie simple (boîtes, toits à deux pans, tubes, disques), peinte par ordre de
             profondeur (peintre), suréchantillonnée 3 fois. Premier passage : des formes simples, pas un modèle détaillé.

Chaque sprite sort en deux images : l'objet (couleurs de plein jour : la page l'assombrit la nuit, comme les vivants) et
ses LUMIÈRES (ampoules et halos sur fond transparent, posées sans assombrissement le soir). Échelle : K px d'image par px de
mosaïque du niveau 8. Le script imprime, pour chaque sprite, l'ancre (le point au sol posé sur la position de l'installation)
à recopier dans le catalogue `sprites:` du YAML.

    python3 script/occupations_sprites.py            # écrit app/assets/images/diorama/occupations/*.png
Dépendances : numpy, Pillow.
"""
import importlib.util
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, "..", "app", "assets", "images", "diorama", "occupations")
NANCY3D = os.environ.get("NANCY3D", os.path.expanduser("~/Documents/nancy-3d"))

A8 = np.array([[2.1261, -0.7739, 0.0], [-0.4974, -1.3667, -1.7333]])   # px du niveau 8 par mètre (L93 x, y, z)
VERS_OEIL = np.array([-0.26200263, -0.71984631, 0.64278761])
ECHELLE = 2.2626
K = 4          # px d'image par px du niveau 8 (le niveau 9 du diorama vaut 2 : marge pour les écrans denses)
SS = 3         # suréchantillonnage du dessin


def soleil():
    a, e = math.radians(140.0), math.radians(45.0)
    return np.array([math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)])


SOLEIL = soleil()


def rgb(hexa):
    hexa = hexa.lstrip("#")
    return np.array([int(hexa[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


# ─── Repère local d'une installation : a le long de l'axe (relèvement `cap` en degrés, grille L93), b à sa droite, z en haut.
def repere(cap):
    c = math.radians(cap)
    ea, eb = np.array([math.sin(c), math.cos(c), 0.0]), np.array([math.cos(c), -math.sin(c), 0.0])
    return lambda a, b, z: a * ea + b * eb + np.array([0.0, 0.0, z])


class Scene:
    """Primitives 3D (m, L93 local, pied à l'origine) peintes de la plus lointaine à la plus proche."""

    def __init__(self):
        self.prims, self.lumieres = [], []

    def face(self, pts, couleur, contour=True, double=False, eclat=None, sol=False):
        """`sol` : surface posée au sol (glace, marquages), peinte avant tout le reste."""
        pts = np.array(pts, float)
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        n /= max(np.linalg.norm(n), 1e-9)
        if n @ VERS_OEIL < 0:
            if not double:
                return
            n = -n
        lam = max(0.0, n @ SOLEIL)
        f = 0.58 + 0.52 * lam if eclat is None else eclat
        col = np.clip(rgb(couleur) * f, 0, 255)
        cle = (pts @ VERS_OEIL).mean() - (1e6 if sol else 0)
        self.prims.append(("poly", cle, pts, col, contour))

    def boite(self, R, a0, a1, b0, b1, z0, z1, couleur, toit=None):
        c = [R(a, b, z) for z in (z0, z1) for b in (b0, b1) for a in (a0, a1)]
        for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.face([c[i] for i in idx], toit if (idx == (4, 6, 7, 5) and toit) else couleur)

    def tube(self, p, q, largeur_m, couleur, pas_m=1.5):
        p, q = np.asarray(p, float), np.asarray(q, float)
        n = max(1, int(np.linalg.norm(q - p) / pas_m))
        for i in range(n):
            u, v = p + (q - p) * i / n, p + (q - p) * (i + 1) / n
            self.prims.append(("seg", ((u + v) / 2) @ VERS_OEIL, (u, v), rgb(couleur), largeur_m))

    def disque(self, p, r_m, couleur, contour=False):
        p = np.asarray(p, float)
        self.prims.append(("disque", p @ VERS_OEIL + r_m, p, rgb(couleur), (r_m, contour)))

    def lumiere(self, p, couleur="#FFD98A", halo_m=0.9, coeur_m=0.16, visible=True):
        """Une ampoule : point clair sur l'objet (s'il est vu) et halo dans l'image des lumières."""
        if visible:
            self.disque(p, coeur_m, couleur)
        self.lumieres.append((np.asarray(p, float), rgb(couleur), halo_m, coeur_m))


def bornes(points):
    S = np.array(points) @ A8.T
    return S[:, 0].min(), S[:, 1].min(), S[:, 0].max(), S[:, 1].max()


def rendre(scene, marge_m=1.5):
    """(image RGBA, image des lumières RGBA, ancre [x, y] en px d'image) à K px par px du niveau 8."""
    pts = [np.zeros(3)]
    for kind, _, g, _, extra in scene.prims:
        if kind == "poly":
            pts += list(g)
        elif kind == "seg":
            pts += list(g)
        else:
            pts.append(g)
    pts += [p for p, *_ in scene.lumieres]
    x0, y0, x1, y1 = bornes(pts)
    m = marge_m * ECHELLE
    x0, y0, x1, y1 = math.floor(x0 - m), math.floor(y0 - m), math.ceil(x1 + m), math.ceil(y1 + m)
    f = K * SS
    W, H = int((x1 - x0) * f), int((y1 - y0) * f)
    ecran = lambda p: ((np.asarray(p) @ A8.T - [x0, y0]) * f)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    trait = max(1, round(0.55 * SS))
    for kind, _, g, col, extra in sorted(scene.prims, key=lambda t: t[1]):
        c = tuple(int(v) for v in col) + (255,)
        sombre = tuple(int(v * 0.5) for v in col) + (255,)
        if kind == "poly":
            xy = [tuple(ecran(p)) for p in g]
            d.polygon(xy, fill=c, outline=sombre if extra else None, width=trait if extra else 1)
        elif kind == "seg":
            u, v = ecran(g[0]), ecran(g[1])
            d.line([tuple(u), tuple(v)], fill=c, width=max(1, int(extra * ECHELLE * f)))
        else:
            r, contour = extra
            q, rp = ecran(g), max(1.0, r * ECHELLE * f)
            d.ellipse([q[0] - rp, q[1] - rp, q[0] + rp, q[1] + rp], fill=c, outline=sombre if contour else None)
    lu = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dl, dh = ImageDraw.Draw(lu), ImageDraw.Draw(halo)
    for p, col, halo_m, coeur_m in scene.lumieres:
        q = ecran(p)
        rh, rc = halo_m * ECHELLE * f, max(1.5, coeur_m * ECHELLE * f)
        dh.ellipse([q[0] - rh, q[1] - rh, q[0] + rh, q[1] + rh], fill=tuple(int(v) for v in col) + (110,))
        clair = tuple(int(255 - (255 - v) * 0.3) for v in col) + (255,)
        dl.ellipse([q[0] - rc, q[1] - rc, q[0] + rc, q[1] + rc], fill=clair)
    halo = halo.filter(ImageFilter.GaussianBlur(radius=max(2, 0.45 * ECHELLE * f)))
    lu = Image.alpha_composite(halo, lu)
    ancre = ecran(np.zeros(3)) / SS
    return reduire(im), reduire(lu), [round(float(ancre[0]), 1), round(float(ancre[1]), 1)]


def reduire(im):
    """Divise par SS en moyennant la couleur PRÉMULTIPLIÉE (pas de frange sombre au bord)."""
    a = np.asarray(im, np.float32) / 255
    pm = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], -1)
    H, W = pm.shape[0] // SS * SS, pm.shape[1] // SS * SS
    pm = pm[:H, :W].reshape(H // SS, SS, W // SS, SS, 4).mean((1, 3))
    al = pm[..., 3:]
    out = np.concatenate([np.where(al > 0, pm[..., :3] / np.maximum(al, 1e-6), 0), al], -1)
    return Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")


# ─── Grande roue (≈ 33 m, « au pied de l'Arc Héré ») : deux jantes, rayons, nacelles, deux chevalets en A, un socle.
def roue(cap):
    R, s = repere(cap), Scene()
    rayon, centre_z, demi_largeur = 15.0, 17.0, 1.6
    acier, pied = "#E9ECF2", "#B9C2D0"
    n = 18
    s.boite(R, -9, 9, -5.5, 5.5, 0, 0.8, "#8C6B55", toit="#A88466")           # plancher de bois
    s.boite(R, 9.5, 13.5, -2.5, 2.5, 0, 2.6, "#C8483E", toit="#F2EDE4")         # guichet
    for b in (-demi_largeur - 1.2, demi_largeur + 1.2):                           # chevalets
        for a in (-8.5, 8.5):
            s.tube(R(a, b, 0.8), R(0, b * 0.75, centre_z), 0.7, pied)
        s.tube(R(-5.4, b, 6.5), R(5.4, b, 6.5), 0.4, pied)
    s.tube(R(0, -demi_largeur - 1.2, centre_z), R(0, demi_largeur + 1.2, centre_z), 0.9, "#7D8796")   # moyeu
    couleurs = ["#E8443A", "#F2B632", "#3C8FD6", "#5DBB63", "#F4F1EA", "#9B59B6"]
    for i in range(n):
        t0, t1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        for b in (-demi_largeur, demi_largeur):
            p0 = R(rayon * math.cos(t0), b, centre_z + rayon * math.sin(t0))
            p1 = R(rayon * math.cos(t1), b, centre_z + rayon * math.sin(t1))
            s.tube(p0, p1, 0.45, acier)
            s.tube(R(0, b, centre_z), p0, 0.22, acier, pas_m=3)
            for j in range(3):                                                    # ampoules de la jante
                t = t0 + (t1 - t0) * j / 3
                s.lumiere(R((rayon + 0.3) * math.cos(t), b, centre_z + (rayon + 0.3) * math.sin(t)),
                          "#FFE7A8" if i % 2 else "#FFD27A", halo_m=0.8)
        a, z = rayon * math.cos(t0), centre_z + rayon * math.sin(t0)             # nacelle suspendue au point de jante
        s.tube(R(a, -demi_largeur, z), R(a, demi_largeur, z), 0.3, acier)
        s.boite(R, a - 1.0, a + 1.0, -1.1, 1.1, z - 2.6, z - 0.6, couleurs[i % len(couleurs)], toit="#F4F1EA")
    s.lumiere(R(0, demi_largeur + 1.3, centre_z), "#FFF2C8", halo_m=1.6, coeur_m=0.4)
    return s


# ─── Patinoire (40 m × 15 m, programme 2025) : glace, bandes, chalet de location, quelques patineurs, guirlandes de mâts.
def patinoire(cap, longueur=40.0, largeur=15.0):
    R, s = repere(cap), Scene()
    la, lb = longueur / 2, largeur / 2
    s.face([R(-la, -lb, 0.05), R(la, -lb, 0.05), R(la, lb, 0.05), R(-la, lb, 0.05)], "#CFE6F2", eclat=1.0, double=True, sol=True)
    for a in np.arange(-la + 3, la - 2, 6.5):                                     # rayures de lissage de la glace
        s.face([R(a, -lb + 1, 0.06), R(a + 2.2, -lb + 1, 0.06), R(a + 2.2, lb - 1, 0.06), R(a, lb - 1, 0.06)],
               "#E6F4FA", contour=False, eclat=1.0, double=True, sol=True)
    s.face([R(-0.25, -lb, 0.07), R(0.25, -lb, 0.07), R(0.25, lb, 0.07), R(-0.25, lb, 0.07)], "#D9434B",
           contour=False, eclat=1.0, double=True, sol=True)
    h = 1.1
    for (a0, b0), (a1, b1) in (((-la, -lb), (la, -lb)), ((la, -lb), (la, lb)), ((la, lb), (-la, lb)), ((-la, lb), (-la, -lb))):
        n = max(1, int(math.hypot(a1 - a0, b1 - b0) / 4))
        for i in range(n):                                                        # bandes, en panneaux (peintre)
            u0, u1 = i / n, (i + 1) / n
            pa = (a0 + (a1 - a0) * u0, b0 + (b1 - b0) * u0)
            pb = (a0 + (a1 - a0) * u1, b0 + (b1 - b0) * u1)
            s.face([R(*pa, 0), R(*pb, 0), R(*pb, h), R(*pa, h)], "#F7F7F4", double=True)
            s.face([R(*pa, h - 0.25), R(*pb, h - 0.25), R(*pb, h), R(*pa, h)], "#2F6DB5", double=True, contour=False)
    s.boite(R, la + 1, la + 7, -4, 4, 0, 2.6, "#9A6A44")                            # location des patins
    s.face([R(la + 0.6, -4.4, 2.6), R(la + 7.4, -4.4, 2.6), R(la + 7.4, 0, 3.8), R(la + 0.6, 0, 3.8)], "#B9473F", double=True)
    s.face([R(la + 0.6, 0, 3.8), R(la + 7.4, 0, 3.8), R(la + 7.4, 4.4, 2.6), R(la + 0.6, 4.4, 2.6)], "#B9473F", double=True)
    rng = np.random.default_rng(20261120)
    habits = ["#D23C3C", "#2E5FA8", "#2F8F5B", "#F0B429", "#7B4BA0", "#20232B"]
    for _ in range(14):                                                            # patineurs (corps, tête)
        a, b = rng.uniform(-la + 2, la - 2), rng.uniform(-lb + 1.5, lb - 1.5)
        s.tube(R(a, b, 0.1), R(a, b, 1.35), 0.5, habits[int(rng.integers(len(habits)))], pas_m=2)
        s.disque(R(a, b, 1.6), 0.24, "#F1C9A5")
    for a in np.linspace(-la, la, 6):                                             # mâts et guirlandes au-dessus des bandes
        for b in (-lb - 0.6, lb + 0.6):
            s.tube(R(a, b, 0), R(a, b, 4.5), 0.18, "#3B3F48", pas_m=5)
    for b in (-lb - 0.6, lb + 0.6):
        for a in np.arange(-la, la + 0.01, 1.6):
            creux = 0.6 * math.sin(math.pi * ((a + la) % 8) / 8)
            s.lumiere(R(a, b, 4.4 - creux), "#FFD98A", halo_m=0.7)
    return s


# ─── Chalets du marché (Grand Village, place Charles III : 60 chalets au programme 2025) : rangées dos à dos, allées.
def chalets(cap, rangees=(("face", -12.0), ("dos", -4.5), ("face", -2.0), ("dos", 5.5), ("face", 8.0)), par_rangee=12):
    R, s = repere(cap), Scene()
    larg, prof, mur, faite = 3.0, 2.5, 2.3, 3.5
    toits = ["#A8392F", "#8E3A2A", "#B24A33", "#7E8B5A"]
    rng = np.random.default_rng(20261120)
    longueur = par_rangee * (larg + 0.25)
    for sens, b in rangees:
        ouvert = 1 if sens == "face" else -1                                     # la façade ouverte regarde l'allée
        for i in range(par_rangee):
            a0 = -longueur / 2 + i * (larg + 0.25)
            a1 = a0 + larg
            b0, b1 = (b, b + prof) if ouvert == 1 else (b - prof, b)
            s.boite(R, a0, a1, b0, b1, 0, mur, "#B07A4C")
            front = b0 if ouvert == 1 else b1
            dehors = -0.02 * ouvert
            s.face([R(a0 + 0.3, front + dehors, 0.9), R(a1 - 0.3, front + dehors, 0.9), R(a1 - 0.3, front + dehors, 2.0),
                    R(a0 + 0.3, front + dehors, 2.0)], "#3A2618", contour=False, double=True)
            for j in range(3):                                                    # étal
                s.disque(R(a0 + 0.7 + j * 0.8, front + dehors * 10, 1.0), 0.22, ["#E8C547", "#D4553C", "#F2EBDD"][j])
            toit = toits[int(rng.integers(len(toits)))]
            m = (b0 + b1) / 2
            s.face([R(a0 - 0.2, b0 - 0.4, mur), R(a1 + 0.2, b0 - 0.4, mur), R(a1 + 0.2, m, faite), R(a0 - 0.2, m, faite)], toit)
            s.face([R(a0 - 0.2, m, faite), R(a1 + 0.2, m, faite), R(a1 + 0.2, b1 + 0.4, mur), R(a0 - 0.2, b1 + 0.4, mur)], toit)
            s.face([R(a0 - 0.2, b0 - 0.4, mur), R(a0 - 0.2, m, faite), R(a0 - 0.2, b1 + 0.4, mur)], "#C69064", double=True)
            s.face([R(a1 + 0.2, b0 - 0.4, mur), R(a1 + 0.2, m, faite), R(a1 + 0.2, b1 + 0.4, mur)], "#C69064", double=True)
            s.face([R(a0 - 0.2, m - 0.25, faite - 0.12), R(a1 + 0.2, m - 0.25, faite - 0.12), R(a1 + 0.2, m + 0.25, faite - 0.12),
                    R(a0 - 0.2, m + 0.25, faite - 0.12)], "#F4F1EA", contour=False, double=True)          # neige du faîte
            bord = b0 - 0.4 if ouvert == 1 else b1 + 0.4
            for a in np.arange(a0, a1 + 0.01, 0.6):                               # guirlande sous l'avant-toit
                s.lumiere(R(a, bord, mur - 0.1), "#FFD27A", halo_m=0.6, coeur_m=0.12)
            s.lumiere(R((a0 + a1) / 2, front + dehors * 5, 1.4), "#FFB45C", halo_m=1.2, coeur_m=0.0, visible=False)
    return s


# ─── Sapin : gabarit conifère de la bibliothèque v18 de nancy-3d, réutilisé, plus une guirlande et une étoile.
def sapin(hauteur=20.0, rayon=4.3):
    chemin = os.path.join(NANCY3D, "rapports", "jeu-video-v2", "scripts", "v18-sprites-arbres.py")
    spec = importlib.util.spec_from_file_location("v18_sprites_arbres", chemin)
    v18 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v18)
    v18.R_REF = rayon
    fut = 1.2
    h = (hauteur - fut) / 0.98

    def gabarit(famille, k, rng):  # celui de v18 (6 lobes empilés) pour un fût plus élancé : 9 lobes plus minces
        lobes = [(np.array([0, 0, fut + h * f]), np.array([rayon * (1 - f) * 1.05, rayon * (1 - f) * 1.05, h * 0.12]))
                 for f in np.linspace(0, 0.86, 9)]
        return lobes, fut, 0

    v18.gabarit = gabarit
    sp = v18.cuire("conifere", 0, 20261006)
    res = v18.RES                                       # échantillons par px du niveau 8 (12)
    rgbp, a, prof, ancre = sp["rgb"], sp["a"], sp["prof"], sp["ancre"]
    Hh, Ww = a.shape
    col = np.where(a[..., None] > 0, rgbp / np.maximum(a[..., None], 1e-6), 0)
    im = Image.fromarray(np.concatenate([np.clip(col, 0, 255), a[..., None] * 255], -1).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(im)
    ecran = lambda p: np.asarray(p) @ A8.T * res + ancre
    lumieres = []
    sommet = fut + h * 0.98
    rng = np.random.default_rng(20261120)
    # guirlande : 8 tours de spirale, une ampoule tous les 0,5 m ; vue seulement si elle est devant le feuillage
    tours, pas = 8, 0.5
    z, t = fut + 0.8, 0.0
    while z < sommet - 1.2:
        r = rayon * 1.05 * max(0.0, 1 - (z - fut) / h) + 0.15
        p = np.array([r * math.cos(t), r * math.sin(t), z])
        q = ecran(p)
        i, j = int(q[1]), int(q[0])
        if 0 <= i < Hh and 0 <= j < Ww and a[i, j] > 0 and p @ VERS_OEIL >= prof[i, j] - 0.6:
            lumieres.append((p, q))
        dz = (sommet - fut) / (tours * 2 * math.pi)
        dt = pas / math.hypot(max(r, 0.5), dz * 2 * math.pi / (2 * math.pi) * 2 * math.pi)
        t += dt
        z += dz * dt
    for p, q in lumieres:
        rc = 0.17 * ECHELLE * res
        d.ellipse([q[0] - rc, q[1] - rc, q[0] + rc, q[1] + rc], fill=(255, 222, 140, 255))
    # motifs colorés (boules), posés sur la surface vue
    for _ in range(60):
        z = rng.uniform(fut + 1, sommet - 2)
        th = rng.uniform(-math.pi, math.pi)
        r = rayon * 1.05 * max(0.0, 1 - (z - fut) / h)
        p = np.array([r * math.cos(th), r * math.sin(th), z])
        q = ecran(p)
        i, j = int(q[1]), int(q[0])
        if 0 <= i < Hh and 0 <= j < Ww and a[i, j] > 0 and p @ VERS_OEIL >= prof[i, j] - 0.6:
            rc = 0.32 * ECHELLE * res
            c = [(214, 52, 58), (46, 104, 196), (240, 190, 60), (180, 70, 160)][int(rng.integers(4))]
            d.ellipse([q[0] - rc, q[1] - rc, q[0] + rc, q[1] + rc], fill=c + (255,), outline=tuple(v // 2 for v in c) + (255,))
    # étoile au sommet (la boîte de l'image est agrandie vers le haut pour la loger)
    marge = int(2.2 * ECHELLE * res)
    grand = Image.new("RGBA", (Ww, Hh + marge), (0, 0, 0, 0))
    grand.paste(im, (0, marge))
    ancre = ancre + [0, marge]
    q = np.array([0, 0, sommet + 0.6]) @ A8.T * res + ancre
    etoile = [(q[0] + (1.1 if k % 2 == 0 else 0.45) * ECHELLE * res * math.sin(k * math.pi / 5),
               q[1] - (1.1 if k % 2 == 0 else 0.45) * ECHELLE * res * math.cos(k * math.pi / 5)) for k in range(10)]
    ImageDraw.Draw(grand).polygon(etoile, fill=(255, 214, 90, 255), outline=(176, 120, 30, 255))
    # lumières : halos des ampoules et de l'étoile
    lu = Image.new("RGBA", grand.size, (0, 0, 0, 0))
    halo = Image.new("RGBA", grand.size, (0, 0, 0, 0))
    dl, dh = ImageDraw.Draw(lu), ImageDraw.Draw(halo)
    for p, qq in lumieres:
        qq = qq + [0, marge]
        rh, rc = 0.8 * ECHELLE * res, 0.2 * ECHELLE * res
        dh.ellipse([qq[0] - rh, qq[1] - rh, qq[0] + rh, qq[1] + rh], fill=(255, 205, 120, 110))
        dl.ellipse([qq[0] - rc, qq[1] - rc, qq[0] + rc, qq[1] + rc], fill=(255, 244, 214, 255))
    rh = 3.0 * ECHELLE * res
    dh.ellipse([q[0] - rh, q[1] - rh, q[0] + rh, q[1] + rh], fill=(255, 220, 130, 150))
    dl.polygon(etoile, fill=(255, 240, 180, 255))
    halo = halo.filter(ImageFilter.GaussianBlur(radius=0.5 * ECHELLE * res))
    lu = Image.alpha_composite(halo, lu)
    # 12 échantillons par px du niveau 8 → K
    f = res // K
    global SS
    garde, SS = SS, f
    objet, lum = reduire(grand), reduire(lu)
    SS = garde
    return objet, lum, [round(float(ancre[0]) / f, 1), round(float(ancre[1]) / f, 1)], len(lumieres)


def ecrire(nom, objet, lum, ancre):
    os.makedirs(SORTIE, exist_ok=True)
    objet.save(os.path.join(SORTIE, f"{nom}.png"), optimize=True)
    lum.save(os.path.join(SORTIE, f"{nom}-lumieres.png"), optimize=True)
    print(f"  {nom}: {objet.width} × {objet.height} px, ancre_px: {ancre}, px_par_pixel_mosaique: {K}", flush=True)


def main():
    # Caps (relèvement de grille L93 de l'axe long de chaque place, mesuré sur les contours OSM, voir le YAML).
    CAP_CARRIERE = float(os.environ.get("CAP_CARRIERE", "-26.8"))
    CAP_CHARLES3 = float(os.environ.get("CAP_CHARLES3", "-28.1"))
    seuls = set(sys.argv[1:])
    if not seuls or "sapin" in seuls:
        objet, lum, ancre, n = sapin()
        print(f"  (sapin : {n} ampoules de guirlande vues)")
        ecrire("sapin", objet, lum, ancre)
    for nom, fabrique in (("grande-roue", lambda: roue(CAP_CARRIERE)), ("patinoire", lambda: patinoire(CAP_CARRIERE)),
                          ("chalets", lambda: chalets(CAP_CHARLES3))):
        if seuls and nom not in seuls:
            continue
        ecrire(nom, *rendre(fabrique()))


if __name__ == "__main__":
    main()
