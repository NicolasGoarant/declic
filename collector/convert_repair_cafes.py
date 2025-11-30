import pandas as pd

SOURCE_CSV = "repair_cafes_personnalises.csv"   # ton fichier cafés
TEMPLATE_CSV = "opportunities_local.csv"        # pour récupérer le header
OUTPUT_CSV = "opportunities_local_repair_cafes.csv"

# On lit le csv des repair cafés
cafes = pd.read_csv(SOURCE_CSV)

# On lit le fichier template pour avoir les bonnes colonnes dans le bon ordre
template = pd.read_csv(TEMPLATE_CSV)
out = pd.DataFrame(columns=template.columns)

for _, row in cafes.iterrows():
    # Mapping des colonnes
    title = row.get("Nom", "").strip()
    description = str(row.get("Notes", "")).strip()
    category = str(row.get("Catégorie", "")).strip().lower() or "ecologiser"
    organization = str(row.get("Organisation", "")).strip()
    location = str(row.get("Adresse", "")).strip()
    time_commitment = str(row.get("Calendrier", "")).strip()
    website = str(row.get("Site web", "")).strip()
    image_url = str(row.get("Photo", "")).strip()

    out_row = {
        "title":          title,
        "description":    description,
        "category":       category,          # ex: "ecologiser"
        "organization":   organization,
        "location":       location,
        "time_commitment": time_commitment,
        "latitude":       "",                # à compléter plus tard si besoin
        "longitude":      "",
        "is_active":      True,
        "tags":           "repair café,réemploi,zéro déchet",
        "image_url":      image_url,
        "source_url":     website,
    }

    out = pd.concat([out, pd.DataFrame([out_row])], ignore_index=True)

out.to_csv(OUTPUT_CSV, index=False)
print(f"✅ Fichier généré : {OUTPUT_CSV}")
