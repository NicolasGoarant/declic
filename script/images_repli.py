#!/usr/bin/env python3
"""Images de repli 1200 x 630 (partage Open Graph, fiches sans photo), aux couleurs de Déclic.

    python3 script/images_repli.py

Écrit dans app/assets/images/ :
  og_default.jpg                      les six icônes de catégorie
  fallback-opportunity.jpg            les cinq icônes des opportunités
  fallback-opportunity-<clé>.jpg      une par catégorie (fiche sans photo partagée)
  fallback-story.jpg                  l'icône Belles Histoires

Icônes : app/assets/images/markers/original/*.png (celles des pins). Couleurs et libellés :
app/models/categorie.rb.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parent.parent
ICONES = RACINE / "app/assets/images/markers/original"
SORTIE = RACINE / "app/assets/images"
POLICE = "/usr/share/fonts/truetype/noto/NotoSans-ExtraBold.ttf"
POLICE_TEXTE = "/usr/share/fonts/truetype/noto/NotoSans-SemiBold.ttf"

L, H = 1200, 630
VIOLET_CLAIR = (123, 92, 255)   # #7b5cff
VIOLET_FONCE = (69, 39, 217)    # #4527d9
BLANC = (255, 255, 255)

CATEGORIES = [  # clé, libellé, couleur (Categorie::TOUTES)
    ("ecologiser", "Écologiser", "#82C162"),
    ("entreprendre", "Entreprendre", "#F8910E"),
    ("rencontres", "Rencontrer", "#EBBF60"),
    ("formation", "Se former", "#5A75E8"),
    ("benevolat", "S'engager", "#E85DAB"),
    ("histoires", "Belles Histoires", "#9472F6"),
]


def rvb(hexa):
    return tuple(int(hexa[i:i + 2], 16) for i in (1, 3, 5))


def fond():
    """Dégradé diagonal violet, deux halos clairs."""
    img = Image.new("RGB", (L, H))
    px = img.load()
    for y in range(H):
        for x in range(L):
            t = (x / L * 0.6 + y / H * 0.4)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(VIOLET_CLAIR, VIOLET_FONCE))
    halo = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(halo)
    d.ellipse((760, -220, 1420, 440), fill=(255, 255, 255, 26))
    d.ellipse((-260, 380, 380, 1020), fill=(255, 255, 255, 18))
    return Image.alpha_composite(img.convert("RGBA"), halo)


def icone(cle, taille):
    """Icône recadrée sur ses pixels visibles, mise au carré."""
    src = Image.open(ICONES / f"{cle}.png").convert("RGBA")
    src = src.crop(src.getbbox())
    cote = max(src.size)
    carre = Image.new("RGBA", (cote, cote), (0, 0, 0, 0))
    carre.paste(src, ((cote - src.width) // 2, (cote - src.height) // 2))
    return carre.resize((taille, taille), Image.LANCZOS)


def pastille(img, cle, centre, taille, couleur=None):
    """Icône sur un disque blanc (liseré de la couleur de catégorie)."""
    d = ImageDraw.Draw(img)
    r = taille // 2 + taille // 7
    cx, cy = centre
    d.ellipse((cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8), fill=(255, 255, 255, 60))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BLANC,
              outline=rvb(couleur) if couleur else None, width=max(4, taille // 30))
    ic = icone(cle, taille)
    img.alpha_composite(ic, (cx - taille // 2, cy - taille // 2))


def logo(img, x, y, echelle=1.0):
    d = ImageDraw.Draw(img)
    c = round(96 * echelle)
    d.rounded_rectangle((x, y, x + c, y + c), radius=round(26 * echelle), fill=BLANC)
    f = ImageFont.truetype(POLICE, round(62 * echelle))
    d.text((x + c / 2, y + c / 2 + 2), "D", font=f, fill=VIOLET_FONCE, anchor="mm")
    f2 = ImageFont.truetype(POLICE, round(84 * echelle))
    d.text((x + c + round(26 * echelle), y + c / 2 + 4), "Déclic", font=f2, fill=BLANC, anchor="lm")


def texte(img, x, y, lignes, taille=38):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(POLICE_TEXTE, taille)
    for i, ligne in enumerate(lignes):
        d.text((x, y + i * round(taille * 1.35)), ligne, font=f, fill=(255, 255, 255, 235))


def etiquette(img, x, y, libelle, couleur):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(POLICE, 34)
    larg = d.textlength(libelle, font=f)
    d.rounded_rectangle((x, y, x + larg + 48, y + 64), radius=32, fill=rvb(couleur))
    r, v, b = rvb(couleur)
    encre = (29, 26, 43) if (0.2126 * r + 0.7152 * v + 0.0722 * b) / 255 > 0.55 else BLANC
    d.text((x + 24, y + 32), libelle, font=f, fill=encre, anchor="lm")


def enregistrer(img, nom):
    img.convert("RGB").save(SORTIE / nom, "JPEG", quality=88, optimize=True, progressive=True)
    print("écrit", SORTIE / nom)


def ligne_icones(img, cles, y, taille):
    pas = (L - 140) / len(cles)
    for i, cle in enumerate(cles):
        couleur = next(c for k, _, c in CATEGORIES if k == cle)
        pastille(img, cle, (round(70 + pas * (i + 0.5)), y), taille, couleur)


def main():
    # Image de partage par défaut : logo, accroche, les six catégories.
    img = fond()
    logo(img, 90, 90)
    texte(img, 92, 225, ["Rencontres, opportunités et belles histoires", "pour faire bouger le Grand Nancy."])
    ligne_icones(img, [c[0] for c in CATEGORIES], 470, 104)
    enregistrer(img, "og_default.jpg")

    # Opportunité sans photo, catégorie inconnue : les cinq catégories d'opportunités.
    img = fond()
    logo(img, 90, 90)
    texte(img, 92, 225, ["Une opportunité à saisir près de chez vous."])
    ligne_icones(img, [c[0] for c in CATEGORIES if c[0] != "histoires"], 450, 120)
    enregistrer(img, "fallback-opportunity.jpg")

    # Une image par catégorie d'opportunité, et celle des Belles Histoires.
    for cle, libelle, couleur in CATEGORIES:
        img = fond()
        logo(img, 90, 110)
        if cle == "histoires":
            texte(img, 92, 260, ["Des parcours qui inspirent,", "près de chez vous."], 42)
        else:
            texte(img, 92, 260, ["Une opportunité à saisir", "près de chez vous."], 42)
        etiquette(img, 92, 430, libelle, couleur)
        pastille(img, cle, (930, 315), 300, couleur)
        enregistrer(img, "fallback-story.jpg" if cle == "histoires" else f"fallback-opportunity-{cle}.jpg")


if __name__ == "__main__":
    main()
