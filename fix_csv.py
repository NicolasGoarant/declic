#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_csv.py
- Nettoie/normalise le CSV brut du collecteur
- Filtre “agenda culturel”
- Devine une catégorie (par mots-clés) parmi: benevolat, formation, rencontres, entreprendre
- Extrait une date/heure FR et calcule starts_at / ends_at
- Formate une ligne “Quand ? …” (time_commitment) cohérente
- Force la présence d'un lien '🔗 En savoir plus : …' dans description si source_url existe
- Troncature titre à 160 chars
Usage:
  python fix_csv.py collector/opportunities_local.csv -o collector/opportunities_local.fixed.csv
"""

from __future__ import annotations
import csv, re, sys, argparse
from datetime import datetime, timedelta
from dateutil import parser as dateparser

ALLOWED_CATEGORIES = {"benevolat","formation","rencontres","entreprendre"}

CULTURE_BLOCK = re.compile(
    r"\b(concert|spectacle|théâtre|exposition|vernissage|cinéma|festival|"
    r"conférence artistique|musée|danse|opéra|orchestre|scène|billetterie)\b",
    re.I
)

# dates FR usuelles: 3 novembre 2025, 13/11/2025, 13.11.25 etc.
DATE_CAND = re.compile(
    r"(\d{1,2}\s*[/-\.]\s*\d{1,2}\s*[/-\.]\s*\d{2,4}|\d{1,2}\s+\w+\s+\d{4})",
    re.I
)
HOUR_CAND = re.compile(r"(\d{1,2})\s*h\s*(\d{2})?", re.I)

KW = {
    "benevolat":   [r"bénévol", r"maraude", r"distributi(on|on)", r"tri de dons", r"accueil", r"entraide"],
    "formation":   [r"formation", r"atelier", r"webinaire", r"initiation", r"certificat", r"HACCP", r"apprendre"],
    "rencontres":  [r"apéro", r"rencontre", r"café[- ]?projet", r"club", r"réseau", r"visite", r"balade"],
    "entreprendre":[r"entrepreneur", r"business plan", r"finance(r|ment)", r"mentorat", r"pro bono", r"juridique"],
}

def guess_category(title: str, desc: str) -> str | "":
    blob = f"{title} {desc}".lower()
    for cat, pats in KW.items():
        for p in pats:
            if re.search(p, blob, re.I):
                return cat
    return ""

def is_culture(title: str, desc: str) -> bool:
    blob = f"{title} {desc}"
    return bool(CULTURE_BLOCK.search(blob))

def parse_datetime_fr(text: str) -> tuple[str, str]:
    """
    Essaie d'extraire un (start, end) ISO8601.
    - Si une heure est trouvée, end = +2h
    - Si seulement une date, start = 09:00 locale, end = 11:00
    Retourne ("","") si rien de fiable.
    """
    if not text:
        return ("","")
    # date
    mdate = DATE_CAND.search(text)
    if not mdate:
        return ("","")
    date_str = mdate.group(1)
    try:
        dt = dateparser.parse(date_str, dayfirst=True, fuzzy=True)
    except Exception:
        return ("","")

    # heure
    mh = HOUR_CAND.search(text[mdate.end():]) or HOUR_CAND.search(text[:mdate.start()])
    if mh:
        hh = int(mh.group(1))
        mm = int(mh.group(2) or 0)
        start = dt.replace(hour=hh, minute=mm, second=0, microsecond=0)
        end = start + timedelta(hours=2)
    else:
        start = dt.replace(hour=9, minute=0, second=0, microsecond=0)
        end = dt.replace(hour=11, minute=0, second=0, microsecond=0)

    # format en ISO (sans timezone)
    return (start.strftime("%Y-%m-%d %H:%M:%S"), end.strftime("%Y-%m-%d %H:%M:%S"))

def build_when_line(start_iso: str, end_iso: str, fallback: str) -> str:
    if start_iso and end_iso:
        s = datetime.strptime(start_iso, "%Y-%m-%d %H:%M:%S")
        e = datetime.strptime(end_iso, "%Y-%m-%d %H:%M:%S")
        # ex: Jeudi 13 novembre 2025, 14:00–16:00
        mois = ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"]
        jour = ["lundi","mardi","mercredi","jeudi","vendredi","samedi","dimanche"][s.weekday()]
        return f"{jour.capitalize()} {s.day} {mois[s.month-1]} {s.year}, {s.strftime('%H:%M')}–{e.strftime('%H:%M')}"
    return fallback

def ensure_learn_more(desc: str, source_url: str) -> str:
    if not source_url:
        return desc
    if "En savoir plus" in desc or "🔗" in desc:
        return desc
    sep = "\n\n" if desc and not desc.endswith("\n") else "\n"
    return f"{desc}{sep}🔗 En savoir plus : {source_url}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input_csv")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    kept, ignored = 0, 0

    headers_out = [
        "title","description","category","organization","location",
        "time_commitment","starts_at","ends_at","latitude","longitude",
        "is_active","tags","image_url","source_url"
    ]

    rows_out = []
    with open(args.input_csv, "r", encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            title = (row.get("title") or "").strip()
            desc  = (row.get("description") or "").strip()
            src   = (row.get("source_url") or "").strip()

            if not title:
                ignored += 1
                continue

            # Filtre agenda culturel
            if is_culture(title, desc):
                ignored += 1
                continue

            # Titre max 160
            title = title[:160]

            # Catégorie
            cat = (row.get("category") or "").strip().lower()
            if cat not in ALLOWED_CATEGORIES:
                cat = guess_category(title, desc)
            if not cat:
                # dernier recours: on jette (évite erreurs à l’import)
                ignored += 1
                continue

            # Dates et "Quand ?"
            start_iso, end_iso = parse_datetime_fr(f"{title} {desc}")
            when_line = build_when_line(start_iso, end_iso, "Créneaux réguliers — voir la page de l’organisateur")

            # Description enrichie avec lien
            desc = ensure_learn_more(desc, src)

            rows_out.append({
                "title": title,
                "description": desc,
                "category": cat,
                "organization": (row.get("organization") or "").strip(),
                "location": (row.get("location") or "Nancy & Métropole").strip(),
                "time_commitment": when_line,
                "starts_at": start_iso,
                "ends_at": end_iso,
                "latitude": (row.get("latitude") or "").strip(),
                "longitude": (row.get("longitude") or "").strip(),
                "is_active": "true",
                "tags": (row.get("tags") or "").strip(),
                "image_url": (row.get("image_url") or "").strip(),
                "source_url": src,
            })
            kept += 1

    # écriture
    with open(args.output, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers_out)
        w.writeheader()
        for r in rows_out:
            w.writerow(r)

    print(f"✅ Écrit: {args.output} — lignes conservées: {kept}, ignorées: {ignored}")

if __name__ == "__main__":
    main()
