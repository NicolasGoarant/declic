# Calque « vivants » sur /labo/diorama (20/10/2026)

Planche : `docs/maquettes/vivants-labo-diorama/planche-avant-apres.webp` (place Stanislas aux niveaux 8 et 9, bassin du canal
au niveau 8 ; 1280 × 800, dpr 1, horloge figée à 120 s). Captures pleines : `stanislas-z8-{avant,apres}.webp`.

## Ce qui est porté

- `app/javascript/diorama/vivants.js` : portage du lecteur de la démo nancy-3d
  (`rapports/animations-v1/vivants-demo/index.html`, commit `ddc2ae8`), mode « itinéraires raccordés », réglages repris tels quels :
  - **vélos** : densité ×5 (20 par km et par sens sur piste, 15 sur bande), modèle `velo-detaille`, 10 px g ≤ 2,4, dès le niveau 8 ;
  - **piétons** : 8 px g ≤ 2, dès le niveau 8, foulée de 0,7 m ;
  - **voitures** : 10 px g ≤ 1,5, dès le niveau 7 ;
  - échelle ×1,6, pyramide de sprites pré-réduits, occlusion par colonnes (méthode « clip ») sur la propriété `propriete-toits-v1`,
    toile dimensionnée au pixel d'appareil (correctif du dpr 0,8).
- Une toile à part, posée juste après celle des dalles (sous le HUD et les boutons) : le chargement et le dessin des dalles ne changent pas.
- Activation : `?vivants=1` seulement. Une case « vivants » apparaît alors dans le HUD pour couper ou relancer le calque.
  Crochets : `?vivants-t=S` (horloge figée), `?vivants-densite-velo=P,B` (témoin, par exemple 16,12).
- Côté Rails : `DioramaTuiles::VIVANTS = "vivants-v1"` (nom de jeu proposé par nancy-3d) et `DIORAMA_VIVANTS_URL`, sur le modèle des bateaux.

## Vérifications

- Sans paramètre, la page est **identique au pixel près** à `HEAD` (Stanislas, niveaux 8 et 9, Chromium 1280 × 800).
  Calque coupé par la case : seule la ligne ajoutée au HUD diffère.
- Stanislas niveau 8 : 145 piétons, 2 vélos, 2 voitures, 2,7 à 3,8 ms par image. Bassin du canal (19000, 9200) niveau 8 :
  365 piétons, 63 vélos, 25 voitures, 4,1 ms. Peu de vélos à Stanislas, comme le relevait nancy-3d (§ 15 : 3,88 par image au niveau 8,
  0,08 au niveau 9) : le réseau cyclable passe ailleurs.
- `bin/rails test` : 123 verts (deux nouveaux tests).

## Ce qui est laissé de côté

- **Rien n'est publié.** Le jeu `vivants-v1` n'existe pas sur R2 : sans `DIORAMA_VIVANTS_URL`, `?vivants=1` affiche « indisponibles »
  et la page continue de fonctionner. Le paquet de nancy-3d (`paquet-v1`) n'a ni vélos ni bus : pour la vérification, un paquet LOCAL
  a été composé à partir des fichiers de la démo (calques `calques-50/{vehicules,pietons,velos}.json`, `repere.json`, atlas et
  pyramide de sprites, modèles filtrés), et servi en CORS. Avant toute publication, il faut trancher entre un jeu séparé et un
  `mobiles-v7` (`rapport-paquet-vivants-v1.md`).
- **Bus et trolleybus** : « premier lot, non réglé » dans la démo (lignes confondues, arrêts à trancher).
- **Correctif des toits jv2** (`occlusion-toits-jv2.json`) : il ne vaut que pour le style jeu-video-v2, alors que /labo/diorama affiche toits-v1.
- **Neige, nuit, fenêtres** (vivant jv2) : ce sont des recettes de rendu des dalles du style jeu-video-v2, pas un calque animé.
  Elles ne sont pas reportées (voir NOTES, réglages du 30/09). /labo/diorama n'a pas d'ambiances.
- Points ouverts : les pins d'opportunités sont dessinés sur la toile des dalles, donc **sous** les vivants. Rien n'est sous
  `prefers-reduced-motion`. Il n'existe pas de chargement différé : environ 13 Mo de données et la préparation des calques au chargement,
  ce que le rapport du paquet chiffre à environ 0,9 s de fil principal sous Node.
