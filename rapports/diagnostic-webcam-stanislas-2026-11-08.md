# Diagnostic : refléter les installations de la place Stanislas dans le diorama, à partir de la webcam

Rédigé le 08/11/2026. Diagnostic seul : aucun code, aucune base, aucun asset modifié. Captures et script de test hors dépôt (scratchpad de session).

## Recommandation

**Faisable avec des réserves.** Techniquement c'est simple et peu coûteux. Deux réserves pèsent :

1. **Le droit d'usage n'est pas établi** : rien n'autorise ni n'interdit la capture automatisée. À clarifier par écrit avant toute construction.
2. **Le besoin réel est plus étroit que prévu** : en 2025, patinoire, grande roue et marché de Noël n'étaient pas sur la place Stanislas (voir § 4). Sur cette place, seul le sapin (et le spectacle son et lumière, non classable en image fixe) est un candidat sérieux. Le mécanisme se réduit alors à un interrupteur « sapin », qu'une date saisie à la main ferait aussi bien.

## 1. Droit d'usage : point à clarifier

- La page `nancy.fr/nancy-la-ville/webcam` n'a **aucune mention** de réutilisation, de fréquence ni d'attribution. Les images sont intégrées par iframe depuis **Skaping** (`skaping.com/nancy/place-stanislas`, statique ; `/live`, flux HLS Quanteec). Une vue ViewSurf (`pv.viewsurf.com/1744/…`) figure aussi dans la page.
- `nancy.fr/mentions-legales` : « Photographies : ©Ville de Nancy, ©Métropole du Grand Nancy, sauf mention contraire ». Pas de licence de réutilisation, pas de clause sur l'extraction automatisée. Une PRADA (personne responsable de l'accès aux documents administratifs et de la réutilisation des données publiques) est désignée : `pradanancy@nancy.fr`.
- Skaping : `robots.txt` n'interdit pas les images de la webcam (il bloque `/ccl.php`, `/showroom/`, `/player/tv`, certaines URL `/about/`). Ses mentions légales (`about.skaping.com/cgu/`) n'ont pas été lues en entier : **clause sur la reproduction non vérifiée**.
- Conclusion : le silence n'est pas une autorisation. Je ne suppose rien. Les images sont © Ville de Nancy, hébergées par un prestataire qui a ses propres conditions.
- **À faire** : écrire à la PRADA et à Skaping (usage non commercial, une image toutes les 10 à 30 min, aucune republication de l'image : seule une étiquette « sapin présent » en sort). Les images ne seraient jamais stockées ni affichées.
- Point favorable, à ne pas surévaluer : si seul le résultat (un booléen) est publié et que l'image est jetée après analyse, l'atteinte aux droits est faible. Cela ne remplace pas l'accord.

## 2. Caractéristiques techniques

| Élément | Constat (08/11/2026) |
|---|---|
| Format | JPEG statique par vignette horodatée, plus un flux vidéo HLS séparé |
| URL | `https://skaping.s3.gra.io.cloud.ovh.net/nancy-1/AAAA/MM/JJ/large/HH-MM.jpg` (1280×720, 113 Ko) et la même sans `large/` (3840×2160, 836 Ko) |
| Récupération | `curl` simple, **sans navigateur, sans blocage** observé (HTTP 200, User-Agent ordinaire) |
| Caméra | Axis C1 (Exif) ; l'URL de la dernière image est dans le HTML de la page Skaping (`og:image`) |
| Cadence | Une image toutes les **10 min** (minutes en `x1` : sondées 14-01, 14-11, 14-21, 15-51, 16-01) |
| Rétention | Courte ou lacunaire : 15-01 à 15-31 renvoient 403 (absentes) alors que 15-51 existe. Impossible de reconstituer l'historique des années passées par ce canal |
| Fragilité | Le chemin S3 et le format de page ne sont pas un contrat : ils peuvent changer sans préavis |

Le cadrage n'est pas fixe pour toujours (caméra sur l'Hôtel de ville, orientée vers l'Arc Héré ; la page propose aussi une vue depuis le Musée des Beaux-Arts et la place de la Carrière).

## 3. Test de classification par IA

Essai du jour (image `16-01.jpg`, 1280×720, 08/11 16:01). Ce que je vois moi-même : un grand sapin à gauche de la statue de Stanislas, la grande roue en arrière-plan derrière l'Arc, ni patinoire, ni chalets, ni scène.

- **Haiku 4.5** (le modèle d'`AiEnricher`), 2 appels, prompt libre avec sortie JSON : sapin de Noël **trouvé les 2 fois** (confiance 85) ; grande roue trouvée (90) ; patinoire, chalets et scène **correctement écartés** ; position du sapin (35 % ; 25 %) proche du réel (≈ 30 % ; 40 %), position de la roue exacte à ±5 points. Coût ≈ 1 400 jetons d'entrée, 250 de sortie par appel (négligeable).
- Nuance relevée : le 2ᵉ commentaire parle de « période creuse » sans raison fondée sur l'image : le modèle brode un peu dans le texte libre. Sa détection, elle, est correcte.
- Un appel avec `claude-sonnet-5-5` a échoué (mon script lisait mal la réponse, pas d'analyse faite) : pas de comparaison de modèles.
- **Limites** : une seule image, de jour, par temps couvert, avec un sapin très visible et isolé. Aucun test de nuit, sous la pluie, sapin en cours de montage ou partiellement masqué, patinoire ou chalets présents (donc cas positifs non testés pour ces classes). Ce test montre que c'est plausible, il ne mesure pas de fiabilité.

## 4. Correspondance avec le diorama

Ce que montre la recherche (sources non officielles, pas de plan trouvé) :

- **Patinoire** et **grande roue** (33 m) : place de la Carrière en 2025, pas Stanislas. La roue qu'on voit sur la webcam est derrière l'Arc : c'est celle de la Carrière.
- **Marché de Noël / Grand Village de Saint-Nicolas** : place Charles III en 2025.
- **Place Stanislas** : spectacle son et lumière / vidéo-mapping (21/11/2025 → 04/01/2026) et un sapin (21 m, source sans date précise).
- Les emplacements semblent se répéter d'une édition à l'autre (les pages mélangent 2025 et 2026), sans confirmation officielle.

Position dans le diorama : place Stanislas centrée en `lat 48.69355, lon 6.18325` (`reglages.js:272`), repère mosaïque niveau 8 en pixels (Lambert-93 dans nancy-3d). Sur la capture, le sapin se tient juste derrière la statue de Stanislas, à gauche, à une quinzaine de mètres (estimation à l'œil, orientation non vérifiée). **Les coordonnées pixel exactes ne sont pas calculées** : il faut projeter un point L93 mesuré sur le terrain ou sur l'orthophoto ; c'est une demi-heure de travail, pas un obstacle. Patinoire (Carrière) et marché (Charles III) devraient être placés à part, et ne sont pas vus par cette webcam.

## 5. Assets à créer (style jeu vidéo actuel)

| Installation | Où | Asset | Priorité |
|---|---|---|---|
| Sapin de Noël | Stanislas | 1 sprite arbre conifère haut (≈ 21 m), éventuellement 1 variante nuit avec guirlandes | **Oui** |
| Spectacle son et lumière | Stanislas | Pas de sprite : plutôt un effet d'ambiance du soir (projection sur façade), hors classification image fixe | À discuter |
| Patinoire | Carrière | 1 aplat blanc/bleuté au sol + bandes | Si la webcam de la Carrière est exploitée |
| Grande roue | Carrière | 1 sprite roue (33 m) | Idem |
| Chalets | Charles III | Une dizaine de petits toits ou 1 tuile répétable | Idem |

## 6. Esquisse d'architecture (indicatif)

1. **Collecte** : tâche Scheduler Heroku (comme `veille:quotidien`), toutes les 30 à 60 min en saison (mi-novembre → début janvier), 1 fois par jour hors saison. L'image 1280×720 est téléchargée en mémoire, jamais stockée ni republiée.
2. **Classification** : un passage Haiku (modèle d'`AiEnricher`, sortie JSON contrainte) renvoie `{sapin: bool, confiance}`. Retenir un état seulement après **N lectures concordantes** (ex. 3 sur 24 h), pour absorber les erreurs de nuit et de météo.
3. **Stockage** : une petite table clé/valeur (ou un enregistrement unique) `installations(nom, presente, vue_le, confiance)`, avec un forçage manuel d'administration par-dessus (le dernier mot reste humain).
4. **Diffusion** : un point `GET /diorama/installations.json` mis en cache court ; le contrôleur du diorama le lit au chargement et, si `sapin`, active la couche sprite (même principe que les couches v2 et le mobilier, au pixel de mosaïque fixe).
5. **Repli** : si la webcam est injoignable, garder le dernier état ; au-delà de 7 jours sans lecture, revenir à la règle calendaire.

Alternative sans webcam, à comparer : une règle par dates saisies à la main (sapin du ~15/11 au ~10/01) dans `reglages.js`, vérifiée une fois par an. Coût nul, aucun enjeu de droit, et pour un seul sapin le gain de la webcam est faible.

## Sources
- Page webcam et mentions légales : `nancy.fr/nancy-la-ville/webcam`, `nancy.fr/mentions-legales`
- Skaping : `skaping.com/nancy/place-stanislas`, `skaping.com/robots.txt`, `about.skaping.com/cgu/`
- Emplacements 2025 : recherche web (festivalenfrance.com, nancy-tourisme.fr, saint-nicolas.nancy.fr) ; à confirmer sur `saint-nicolas.nancy.fr`.
