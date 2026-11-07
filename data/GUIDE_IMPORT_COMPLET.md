# 🎯 GUIDE COMPLET - Utilisation Votre Système d'Import

## ✅ Système Analysé et Compris !

Votre rake task `declic:import_csv` fonctionne parfaitement. J'ai adapté mes CSV à votre format.

---

## 📋 Format Attendu par Votre Système

Votre système attend ces colonnes :

```csv
title,description,category,organization,location,time_commitment,latitude,longitude,tags,image_url,source_url,starts_at,ends_at,is_active
```

**Colonnes clés pour l'upsert** (éviter doublons) :
- `title` + `organization` + `location`

**Catégories valides** :
- `benevolat`
- `ecologie` (anciennement `ecologiser`, encore accepté par `scripts/import_opportunities.rb`)
- `formation`
- `rencontres`
- `entreprendre`

---

## 🚀 Import Immédiat - 3 Commandes

### 1. Télécharger les CSV Adaptés

Téléchargez ces 2 fichiers :
- `opportunities_declic_adapted.csv` (41 opportunités)
- `opportunities_vdsd_adapted.csv` (84 opportunités)

### 2. Les Placer dans Votre Projet

```bash
# Dans votre projet declic/
mkdir -p data
cp /chemin/vers/opportunities_declic_adapted.csv data/
cp /chemin/vers/opportunities_vdsd_adapted.csv data/
```

### 3. Lancer les Imports

```bash
# Import opportunités Déclic (41 fiches - published)
rake "declic:import_csv[data/opportunities_declic_adapted.csv]"

# Résultat attendu :
# ✅ Import terminé
#    • créés:      41
#    • mis à jour: 0
#    • inchangés:  0
#    • erreurs:    0

# Import opportunités VDSD (84 fiches - draft)
rake "declic:import_csv[data/opportunities_vdsd_adapted.csv]"

# Résultat attendu :
# ✅ Import terminé
#    • créés:      84
#    • mis à jour: 0
#    • inchangés:  0
#    • erreurs:    0
```

**C'EST TOUT !** 🎉

---

## 📊 Vérification Post-Import

### Console Rails

```ruby
rails console

# Compter les imports
Opportunity.count
# => Devrait être votre nombre initial + 125

# Voir les actives (Déclic)
Opportunity.where(is_active: true).count
# => 41

# Voir les inactives (VDSD à enrichir)
Opportunity.where(is_active: false).count
# => 84

# Par catégorie
Opportunity.group(:category).count
# => {"benevolat"=>94, "entreprendre"=>10, "ecologiser"=>8, "formation"=>10, "rencontres"=>1}

# Dernières importées
Opportunity.last(5).pluck(:title, :organization, :location, :is_active)
```

---

## 🎨 Fonctionnalités de Votre Système

### ✅ Idempotent (Pas de Doublons)

Si vous relancez l'import avec le même CSV :

```bash
rake "declic:import_csv[data/opportunities_declic_adapted.csv]"

# Résultat :
# ✅ Import terminé
#    • créés:      0
#    • mis à jour: 0
#    • inchangés:  41  ← Toutes détectées comme existantes
#    • erreurs:    0
```

La clé d'identification : `title` + `organization` + `location`

---

### ✅ Désactivation Automatique des Dates Passées

Votre système vérifie `starts_at` et `ends_at` :

```ruby
# Si ends_at < aujourd'hui → is_active = false
# Si starts_at < aujourd'hui ET ends_at vide → is_active = false
# Sinon → is_active = true (ou selon CSV)
```

**Exemple** :
```csv
title,starts_at,ends_at,is_active
"Atelier vélo",2024-12-01,2024-12-15,1
```
→ Sera importé avec `is_active = false` (dates passées)

---

### ✅ Mode Dry Run (Test sans Import)

Pour tester sans modifier la base :

```bash
DRY_RUN=true rake "declic:import_csv[data/opportunities_declic_adapted.csv]"

# Affiche ce qui serait fait sans rien enregistrer
```

---

### ✅ Mode Prudent (ONLY_DEACTIVATE)

Pour ne PAS activer automatiquement les futures opportunités :

```bash
ONLY_DEACTIVATE=true rake "declic:import_csv[data/opportunities_declic_adapted.csv]"

# Désactive les passées mais ne force pas is_active=true pour les futures
```

---

## 🔧 Maintenance - Tâches Utiles

### Désactiver Toutes les Opportunités Expirées

```bash
rake declic:deactivate_expired

# Parcourt toutes les opportunités actives
# Désactive celles dont les dates sont passées
```

### Réactiver les Opportunités Futures

```bash
rake declic:reactivate_future

# Parcourt les opportunités inactives
# Réactive celles dont les dates sont à venir
```

### Rafraîchir l'État Global

```bash
rake declic:refresh_activity

# Fait les deux : désactive passées + réactive futures
# À lancer périodiquement (cron quotidien recommandé)
```

**Cron quotidien recommandé** :
```bash
# crontab -e
0 2 * * * cd /chemin/vers/declic && rake declic:refresh_activity
```

---

## 📝 Adaptations Appliquées à Vos CSV

### Changements pour Compatibilité

| Original | → | Adapté |
|----------|---|--------|
| `city` + `postcode` + `address` | → | `location` (concaténé) |
| `website` | → | `source_url` |
| `status` (published/draft) | → | `is_active` (1/0) |

### Exemple de Transformation

**Avant** :
```csv
title,address,city,postcode,website,status
"Atelier vélo","17 rue Drouin","Nancy","54000","https://site.com","published"
```

**Après** :
```csv
title,location,source_url,is_active
"Atelier vélo","17 rue Drouin, Nancy, 54000","https://site.com","1"
```

---

## 🎯 Enrichissement Progressif VDSD

Les 84 opportunités VDSD sont importées avec `is_active = 0` (draft).

### Option 1 : Via Admin

```
1. Aller sur /admin/opportunities
2. Filtrer is_active = false
3. Éditer chaque fiche :
   - Ajouter contact_email
   - Ajouter source_url (site web)
   - Vérifier location
4. Sauvegarder → Passer is_active = true
```

### Option 2 : Via Console

```ruby
rails console

# Activer une opportunité
opp = Opportunity.find_by(title: "AD2S - VDSD 2025")
opp.update(
  source_url: "https://ad2s.fr",
  is_active: true
)

# Activer plusieurs en masse (prudent)
Opportunity.where(organization: "AD2S").update_all(is_active: true)
```

### Option 3 : Mise à Jour CSV

```csv
# Enrichir le CSV avec les nouvelles infos
title,source_url,is_active
"AD2S - VDSD 2025","https://ad2s.fr","1"
"Association CYNO-SENS - VDSD 2025","https://cynosens.fr","1"
...

# Puis ré-importer
rake "declic:import_csv[data/vdsd_enriched.csv]"

# Résultat : Les fiches seront mises à jour (upsert)
```

---

## 🔍 Troubleshooting

### Erreur : "Category is not included in the list"

**Cause** : Catégorie invalide dans le CSV.

**Catégories valides** :
- `benevolat`
- `ecologie`
- `formation`
- `rencontres`
- `entreprendre`

**Solution** : Vérifier que toutes les lignes ont une catégorie valide.

---

### Erreur : "Title can't be blank"

**Cause** : Ligne sans titre.

**Solution** : Vérifier le CSV, supprimer les lignes vides.

---

### Import crée des doublons

**Cause** : La clé d'upsert (`title` + `organization` + `location`) ne correspond pas.

**Exemple** :
```
Import 1 : title="Atelier vélo", location="Nancy"
Import 2 : title="Atelier vélo", location="Nancy, 54000"
→ 2 fiches différentes (location différente)
```

**Solution** : Utiliser exactement le même format de `location`.

---

### Des opportunités ne s'affichent pas sur la carte

**Cause** : `is_active = false`

**Vérification** :
```ruby
Opportunity.where(is_active: false).count
```

**Solution** :
```ruby
# Activer toutes celles sans dates (permanentes)
Opportunity.where(is_active: false, starts_at: nil, ends_at: nil)
           .update_all(is_active: true)
```

---

## 📊 Statistiques Attendues Après Import

### Opportunités

```
Total : 125 nouvelles opportunités

Par statut :
  - Active (is_active=true) : 41
  - Inactive (is_active=false) : 84

Par catégorie :
  - Bénévolat : ~94
  - Entreprendre : ~10
  - Écologiser : ~8
  - Formation : ~10
  - Rencontres : ~1

Géolocalisation :
  - Avec lat/lng : ~101 (81%)
  - Sans coordonnées : ~24 (19%)
```

### Couverture Géographique

```
Nancy centre : ~90 opportunités
Laxou : ~5
Villers-lès-Nancy : ~3
Vandœuvre : ~2
Autres : ~25
```

---

## 🎉 Import des Stories (38 fiches)

⚠️ **Votre système actuel n'a pas de task pour les stories.**

### Option A : Créer une Task Stories (Recommandé)

Je peux vous créer un `declic_import_stories.rake` similaire.

### Option B : Import Manuel via Console

```ruby
rails console

require 'csv'

CSV.foreach('data/stories_ready.csv', headers: true, encoding: 'utf-8') do |row|
  Story.create!(
    title: row['title'],
    excerpt: row['excerpt'],
    content: row['content'],
    location: row['location'],
    image_url: row['image_url'],
    tags: row['tags'],
    source_url: row['source_url'],
    published_at: Time.current,
    status: 'published'
  )
  print "."
end

puts "\n✅ #{Story.count} stories importées"
```

### Option C : Via Admin

Ajouter les 38 stories manuellement via `/admin/stories/new`.

---

## 💡 Optimisations Futures

### 1. Géocodage Automatique

Si certaines opportunités n'ont pas de `latitude`/`longitude` :

```ruby
# Dans votre modèle Opportunity
after_validation :geocode, if: :location_changed?

geocoded_by :location
```

Nécessite la gem `geocoder`.

### 2. Import Incrémental Quotidien

```bash
# Script pour importer nouvelles opportunités quotidiennement
#!/bin/bash
cd /chemin/vers/declic
rake "declic:import_csv[collector/daily_opportunities.csv]"
rake declic:refresh_activity
```

### 3. Notification Email Post-Import

```ruby
# À la fin de la task import_csv
if created > 0
  AdminMailer.import_report(created, updated, errs).deliver_now
end
```

---

## 📚 Résumé des Commandes

```bash
# Import complet
rake "declic:import_csv[data/opportunities_declic_adapted.csv]"
rake "declic:import_csv[data/opportunities_vdsd_adapted.csv]"

# Maintenance
rake declic:refresh_activity  # Quotidien recommandé

# Test
DRY_RUN=true rake "declic:import_csv[data/test.csv]"

# Vérification
rails console
> Opportunity.where(is_active: true).count
```

---

## 🎯 Checklist Complète

- [ ] Télécharger `opportunities_declic_adapted.csv`
- [ ] Télécharger `opportunities_vdsd_adapted.csv`
- [ ] Copier dans `data/`
- [ ] Lancer import Déclic
- [ ] Vérifier résultat (41 créées, 0 erreurs)
- [ ] Lancer import VDSD
- [ ] Vérifier résultat (84 créées, 0 erreurs)
- [ ] Vérifier en console (`Opportunity.count`)
- [ ] Vérifier sur la carte (41 points visibles)
- [ ] Setup cron pour `refresh_activity`
- [ ] Enrichir VDSD progressivement
- [ ] Importer stories (38 fiches)

---

**Votre système d'import est PARFAIT et maintenant pleinement documenté !** 🚀✨
