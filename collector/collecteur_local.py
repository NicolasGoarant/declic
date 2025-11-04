#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Collecteur local — Déclic
- Lit collector/sources_urls.txt (une source par ligne, avec type optionnel)
- Récupère des items depuis des pages HTML, flux RSS, ou PDF (bulletins)
- Écrit un CSV brut collector/opportunities_local.csv
- Le nettoyage/filtrage/enrichissement se fait ensuite via fix_csv.py

Dépendances (voir requirements.txt) :
  requests, beautifulsoup4, lxml, python-dateutil
Optionnelles :
  feedparser (RSS/Atom), pdfminer.six (PDF)
"""

from __future__ import annotations
import os, csv, re, sys, time
from typing import List, Dict, Optional

import requests
from bs4 import BeautifulSoup

# --- Sources optionnelles (ne plantent pas si non installées) ---
try:
    import feedparser  # RSS/Atom
except Exception:
    feedparser = None

try:
    from pdfminer.high_level import extract_text as pdf_extract_text
except Exception:
    pdf_extract_text = None


USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)
TIMEOUT = 30


def fetch(url: str) -> Optional[requests.Response]:
    """GET robuste avec UA et timeout."""
    try:
        r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=TIMEOUT)
        r.raise_for_status()
        return r
    except Exception as e:
        print(f"[WARN] {url} -> {e}")
        return None


def absolutize(base: str, href: str) -> str:
    from urllib.parse import urljoin
    return urljoin(base, href or "")


def visible_text(el) -> str:
    """Texte propre d'un élément HTML."""
    txt = el.get_text(separator=" ", strip=True)
    txt = re.sub(r"\s+", " ", txt).strip()
    return txt


def collect_from_html(url: str) -> List[Dict]:
    """
    Collecte générique depuis une page HTML.
    Heuristique :
      - chaque <article>, <li>, <section>, ou bloc avec un <h1/h2/h3> devient un item
      - on extrait title, description (court), premier lien, première image
    """
    resp = fetch(url)
    if not resp:
        return []
    soup = BeautifulSoup(resp.text, "lxml")

    items: List[Dict] = []

    # préférer <article>, sinon sections, sinon gros <li>
    candidates = soup.select("article")
    if not candidates:
        candidates = soup.select("section")
    if not candidates:
        candidates = soup.select("li")

    # fallback: découpage par titres si aucune structure
    if not candidates:
        for h in soup.select("h1, h2, h3"):
            block_text = []
            sib = h.find_next_sibling()
            steps = 0
            while sib and steps < 6:
                block_text.append(visible_text(sib))
                sib = sib.find_next_sibling()
                steps += 1
            desc = " ".join([t for t in block_text if t]).strip()
            if visible_text(h):
                items.append({
                    "title": visible_text(h)[:160],
                    "description": desc[:1200],
                    "source_url": url,
                    "image_url": "",
                })

    # structures “classiques”
    for node in candidates:
        # Titre
        h = node.select_one("h1, h2, h3")
        title = visible_text(h) if h else ""
        # Desc
        ps = node.select("p")
        desc = ""
        if ps:
            parts = []
            for p in ps[:6]:
                t = visible_text(p)
                if t and len(" ".join(parts + [t])) < 1400:
                    parts.append(t)
            desc = " ".join(parts)
        else:
            desc = visible_text(node)[:1200]

        # Lien (priorité aux boutons/cta)
        link_el = node.select_one("a[href*='http']")
        link = ""
        if link_el and link_el.get("href"):
            link = absolutize(url, link_el["href"])

        # Image
        img = ""
        img_el = node.select_one("img[src]")
        if img_el and img_el.get("src"):
            img = absolutize(url, img_el["src"])

        # Nettoyage sommaire
        if not title:
            # parfois titre dans aria-label / data-* … on se rabat sur 1ères mots
            title = desc[:120].split(".")[0][:160]

        if title:
            items.append({
                "title": title[:160],
                "description": desc[:1800],
                "source_url": link or url,
                "image_url": img,
            })

    # Nettoyage final simple (dédup par (title, source_url))
    seen = set()
    unique = []
    for it in items:
        key = (it.get("title", ""), it.get("source_url", ""))
        if key not in seen and it.get("title"):
            seen.add(key)
            unique.append(it)
    return unique


def collect_from_rss(url: str) -> List[Dict]:
    """Collecte basique depuis un flux RSS/Atom -> items 'title/description/source_url'."""
    if feedparser is None:
        print("[WARN] feedparser non installé. `pip install feedparser` pour activer RSS.")
        return []
    feed = feedparser.parse(url)
    rows: List[Dict] = []
    for e in feed.entries:
        title = (getattr(e, "title", "") or "").strip()
        desc = (getattr(e, "summary", "") or getattr(e, "description", "") or "").strip()
        link = (getattr(e, "link", "") or "").strip()
        if title:
            rows.append({
                "title": title[:160],
                "description": desc[:1800],
                "source_url": link or url,
                "image_url": "",
            })
    return rows


def extract_pdf_text(url: str) -> str:
    """Télécharge un PDF et extrait le texte brut si pdfminer dispo, sinon renvoie ''."""
    if pdf_extract_text is None:
        print("[WARN] pdfminer.six non installé. `pip install pdfminer.six` pour activer PDF.")
        return ""
    import tempfile
    try:
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            r = fetch(url)
            if not r:
                return ""
            tmp.write(r.content)
            tmp_path = tmp.name
        text = pdf_extract_text(tmp_path) or ""
    except Exception as e:
        print(f"[WARN] PDF fail: {e}")
        text = ""
    finally:
        try:
            os.remove(tmp_path)  # type: ignore
        except Exception:
            pass
    return text


def split_pdf_into_items(text: str) -> List[Dict]:
    """
    Heuristique simple : découpe le PDF en 'items' par doubles sauts de ligne.
    Tu pourras raffiner selon la maquette des magazines municipaux.
    """
    items: List[Dict] = []
    for chunk in [c.strip() for c in text.split("\n\n") if c.strip()]:
        lines = chunk.splitlines()
        title = (lines[0] if lines else "")[:160]
        desc = chunk[:1800]
        if title:
            items.append({"title": title, "description": desc})
    return items


def collect_from_mastodon(url: str) -> List[Dict]:
    """
    Optionnel (stub). Pour une implémentation réelle, utiliser l’API Mastodon (token).
    """
    print("[INFO] Mastodon collector non implémenté (stub).")
    return []


def dispatch_collect(kind: str, url: str) -> List[Dict]:
    if kind == "rss":
        return collect_from_rss(url)
    if kind == "pdf":
        text = extract_pdf_text(url)
        items = split_pdf_into_items(text)
        for it in items:
            it["source_url"] = url
        return items
    if kind == "html":
        return collect_from_html(url)
    if kind == "mastodon":
        return collect_from_mastodon(url)
    # fallback: HTML
    return collect_from_html(url)


def main():
    # lecture du fichier de sources
    src_path = os.path.join("collector", "sources_urls.txt")
    if not os.path.isfile(src_path):
        print(f"[ERROR] Fichier introuvable: {src_path}")
        sys.exit(1)

    with open(src_path, "r", encoding="utf-8") as f:
        lines = [ln.strip() for ln in f if ln.strip() and not ln.strip().startswith("#")]

    collected: List[Dict] = []
    for ln in lines:
        parts = ln.split(maxsplit=1)
        if len(parts) == 1:
            kind, url = "html", parts[0]
        else:
            kind, url = parts[0].lower(), parts[1]

        print(f"→ Scrape ({kind}) {url}")
        try:
            rows = dispatch_collect(kind, url)
            print(f"   +{len(rows)} élément(s)")
            collected.extend(rows)
            time.sleep(0.5)  # soft throttle
        except Exception as e:
            print(f"[WARN] {url} -> {e}")

    # écriture du CSV brut
    out_csv = os.path.join("collector", "opportunities_local.csv")
    headers = [
        "title","description","category","organization","location","time_commitment",
        "latitude","longitude","is_active","tags","image_url","source_url"
    ]
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    with open(out_csv, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers)
        w.writeheader()
        for r in collected:
            w.writerow({k: (r.get(k,"") or "") for k in headers})

    print(f"✅ Terminé. Fichier écrit: {out_csv} ({len(collected)} lignes)")


if __name__ == "__main__":
    main()
