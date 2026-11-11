# Rapport final — veille-sources-v2 (11/11/2026)

Branche `veille-sources-v2`, partie de **`main`** (et non de `veille-auto`, entièrement contenue dans `main` et en retard de 29 commits ; `main` est en prod).
Tests : 526 verts (`bin/rails test`), dont 6 (connecteur) + 8 (escalade, tarifs) nouveaux. **Aucun appel réel à l'API Anthropic n'a été fait** : le tri est testé avec un client simulé ; le premier vrai essai reste à faire.

## Sources opérationnelles
- **ICI Lorraine** (Nord et Sud, « à la une ») : vérifié en réel, 65 éléments. Aucune opposition à la fouille de textes trouvée (mentions légales) ; robots.txt n'exclut que GPTBot, ChatGPT-User, Google-Extended. **À confirmer par le président**, comme pour les communes.
- **France 3 Lorraine (Nancy)** : vérifié en réel, 15 éléments. Adresse canonique `franceinfo.fr` (l'ancienne `francetvinfo.fr` redirige, et `Veille::RobotsPolicy` juge son robots.txt illisible : à corriger un jour).
- Déjà en place : Agenda Grand Nancy (donc Ville de Nancy), communes, JeVeuxAider (inactif dans le quotidien, clé requise).

## Sources écartées
- **L'Est Républicain, Le Républicain Lorrain, Vosges Matin** : flux existent, mais CGU : « s'oppose à la fouille de textes et de données », extraction et usage IA interdits sans accord écrit. Cela rejoint la décision du 31/10 (presse en lecture humaine). Pour les activer : accord écrit des éditeurs.
- **Actu Nancy** : pas de flux local (404) ; CGU opposées à la fouille.
- **HelloAsso, France Bénévolat, EFS** : voir `docs/veille.md` (pas d'API publique ni de flux exploitable proprement).
- **Agenda Métropole** : non exposé par l'API mutualisée.

## Écarts avec la demande
1. Les 6 journaux demandés : 2 sur 6 lus (ICI, France 3), car les CGU de 4 sur 6 interdisent ce traitement. Je n'ai pas contourné.
2. « Doublon probable » en sortie IA : fait par le code (déterministe, gratuit) avant l'appel, pas par le modèle.
3. Score de 0 à 1 : stocké de 0 à 100 (existant) ; seuils 0,4/0,7 = 40/70.
4. Étape 4 : déjà en place avant cette branche (statut « à valider », source, score, résumé, Valider/Écarter/À vérifier/Aperçu) ; non modifiée, libellés inchangés.
5. Ni cache de prompt ni lot (batch) : non ajoutés.

## Coût estimé par 100 éléments (estimation, non mesurée)
Hypothèses : prompt système ≈ 4 000 jetons + schéma ≈ 300 + élément ≈ 400 → ≈ 4 700 en entrée ; ≈ 550 en sortie (JSON + réflexion à effort bas) ; grille du 03/11/2026.
- Sonnet 5.5 (2 $/10 $ par million) : ≈ 0,015 $ par élément → **≈ 1,5 $ / 100**.
- Escalade Opus 5.5 (4 $/20 $), si 20 % des éléments tombent entre 40 et 70 : ≈ 0,03 $ × 20 → **+ 0,6 $ / 100**. Total **≈ 2,1 $ / 100 éléments**.
- Pour comparaison : Haiku 5.5 (0,10 $/0,50 $) ≈ 0,08 $ / 100, soit ~25 fois moins (`VEILLE_MODEL=claude-haiku-5-5` ; qualité de classement à comparer sur un échantillon).
- **Attention au plafond** : 30 éléments enrichis par jour ≈ 0,6 $/jour ≈ 19 $/mois avec Sonnet + escalade, au-dessus des 15 $ (`VEILLE_BUDGET_USD_MOIS`) ; le plafond bloquerait en fin de mois. Le flux presse ajoute ~80 éléments/jour, en bonne partie hors sujet. Leviers : Haiku 5.5, prompt caching (entrée ≈ 85 % du coût), `MAX_ENRICHIS`.

## Avant de déployer
- Rien n'est déployé ni poussé. Le quotidien (`Runner::QUOTIDIEN`) inclut désormais `FluxPresse` : décider du modèle et du plafond avant la mise en prod.
- Faire un premier essai sur quelques éléments avec la vraie clé (à régénérer, cf. NOTES) et relire les scores.
