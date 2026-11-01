# Audit de la géolocalisation — 14/10/2026

## Verdict
**Aucune régression de code trouvée : la géolocalisation fonctionne en production** (`www.declic.site`, `main` = `heroku/main` d9b9b3f, v349) quand le navigateur accorde la permission. Aucun commit n'a supprimé ni désactivé le code. Le diagnostic reste donc non établi côté code → phase 2 non lancée (pas de branche `fix-geolocalisation`).

## Causes classées par probabilité
1. **Permission « position » refusée/bloquée dans le navigateur de l'utilisateur** (très probable). Depuis `8a4ed2e` (01/10/2026, « Géolocalisation automatique à l'arrivée »), la page demande la position seule au chargement, sans geste. Chrome/Firefox traitent ces invites comme intrusives (invite discrète, blocage après quelques refus ou fermetures) : le site passe en « bloqué », et le bouton « Me localiser » ne peut plus rien. Seule trace visible : l'alerte « Position indisponible : autorisez… » (`diorama_controller.js` `localisationRefusee`). Reproduit : permission refusée → alerte, aucune position, ni recentrage ni tri.
2. **Ressenti** : sur l'accueil, `localiser: :pastille` n'a plus de pastille « À proximité » ni de tri (`/` n'a ni filtre proximité ni « Plus proches »). Ces contrôles n'existent que sur `/labo/opportunites` (pastille + option « Plus proches ») et `/labo/belles-histoires` (pastille, sans option de tri). Si l'attendu est « tri par distance sur l'accueil », c'est une fonctionnalité absente, pas cassée.
3. Cache : `public/sw.js` (Cache First sur assets, précache `/`) pourrait servir un vieux JS, mais les assets sont empreintés (fingerprint) et le test en navigateur neuf ne le montre pas. À écarter ou à vérifier en vidant les données du site.
4. Écartés : Permissions-Policy (`config/initializers/permissions_policy.rb` → `geolocation :self`, en-tête prod `feature-policy: geolocation 'self'`), CSP (initializer entièrement commenté), HTTPS (`force_ssl`, `isSecureContext` = true), iframe (aucun), importmap (`config/importmap.rb:10` `geoloc_auto`, servi en prod).

## Preuves
- Historique : `git log -S"navigator.geolocation"` ne montre aucune suppression ; code ajouté/maintenu par 8a4ed2e (géoloc auto, 01/10), 558cb56 (pages /labo, 27/09), 78955fd (accueil diorama), 123f6b5 (viewer /labo/diorama).
- Chaîne en place (branche `main` et courante) : `app/views/accueil/_carte.html.erb:19-28` (boutons `diorama#localiser`) → `app/javascript/controllers/diorama_controller.js:1194` `localiser()` → `navigator.geolocation` → `appliquerPosition` (:1204, `setView` + marqueur `.diorama-moi` + événement `diorama:localise`) → `explorateur_controller.js` (:78-151, filtre `proximite` et tri `proches` calculés **côté client**, pas côté serveur). `geoloc_auto.js` importé par `application.js:5`.
- Test réel Playwright sur la prod, position 48.6921 / 6.1844 : `window.declicPosition` renseigné, marqueur `.diorama-moi` présent, clic sur « Me localiser » sans alerte, aucune erreur console. Avec permission refusée : alerte affichée, pas de position.

## Branches
| Branche | Code de géoloc branché sur le bouton ? |
|---|---|
| main (prod) | Oui (accueil, /labo/*, geoloc_auto) |
| veille-auto (courante) | Oui (identique à main) |
| refonte-accueil | Pas de `diorama_controller`/`geoloc_auto` ; seulement l'ancien `shared/_map` et `geo_watch.js` (anciennes pages) |
| ingestion-ia, veille-belles-histoires | Idem : ancien code Leaflet seulement (`home.html.erb`, `opportunities/index`, `stories/index`) |

Les branches anciennes sont simplement antérieures à la refonte, rien n'a été « supprimé ».

## Pages (prod, testées)
| Page | Bouton | Branché | Remarque |
|---|---|---|---|
| `/` (accueil) | Pastille « Me localiser » | Oui | Pas de filtre proximité ni de tri |
| `/labo/accueil` | — | — | 301 vers `/` |
| `/labo/opportunites` | Bouton rond + pastille « À proximité » + tri « Plus proches » | Oui | Chargement lent (timeout `networkidle` à 30 s) |
| `/labo/belles-histoires` | Bouton rond + pastille « À proximité » | Oui | Pas d'option « Plus proches » ; 7 ressources 404 (images) |
| `/labo/diorama` | `#btn-locate` | Oui (script en ligne) | Pas de géoloc auto |
| `/labo/carte` | — | — | Route inexistante (404) |

## Plan de correction proposé (non appliqué, à valider)
1. Confirmer chez l'utilisateur : icône cadenas → Position = « Autoriser » (ou réinitialiser les autorisations du site), puis recharger.
2. Supprimer l'invite automatique au chargement, ou ne la lancer que si la permission est déjà `granted` ; garder la demande au clic sur « Me localiser » (geste utilisateur, jamais bloqué).
3. Quand la permission est `denied`, remplacer l'alerte par un message d'aide dans l'interface (comment réautoriser).
4. Décider si l'accueil doit proposer « À proximité » / « Plus proches » (fonctionnalité à ajouter, hors correctif).
5. Test système : bouton présent sur `/`, `/labo/opportunites`, et tri `proches` ordonné par distance (position simulée Nancy), à ajouter avec le correctif.
6. Examiner les 404 de `/labo/belles-histoires` (hors géoloc).

## Limites
Test fait sur la prod et non sur `localhost:3003` (diorama bloqué en CORS hors `localhost:3000`). Aucun code modifié.

---

# Complément — pourquoi l'invite n'apparaissait pas (14/10/2026, 2e demande)

## Cause exacte
`geoloc_auto.js` (commit 8a4ed2e) posait le drapeau `localStorage["declic:geoloc-auto"]` **avant** d'appeler `getCurrentPosition`, puis `if (dejaDemandee()) return` pour toute visite suivante. Conséquence : **une seule tentative par navigateur, à vie**. Si l'invite était fermée (Firefox « Pas maintenant »), ignorée, ou ratée (onglet fermé, rechargement) lors de la toute première visite, la permission restait en état `prompt` mais le drapeau interdisait de jamais la reproposer. Seul le clic sur « Me localiser » (qui n'a pas de drapeau) redemandait. Aucune des autres conditions (HTTPS, Permissions-Policy, ordre d'initialisation) ne bloque.

## Preuves (Playwright 1.63, profil vierge, `getCurrentPosition` et `permissions.query` espionnés, prod avant correctif)
| Navigateur | Permission | Appel au chargement |
|---|---|---|
| Chromium | vierge (prompt) | `permissions.query → prompt` à ~1,5 s puis `getCurrentPosition` |
| Chromium | granted | oui, position reçue |
| Firefox | vierge (prompt) | oui, à ~1,9 s |
| Firefox | granted | oui, position reçue |
| WebKit (Safari) | — | non testé : le binaire Playwright ne se lance pas ici (bibliothèques système manquantes) |

Donc sur un profil neuf, l'appel part bien ; chez un utilisateur déjà passé une fois, le drapeau bloque. Sous Chromium/Firefox l'invite s'affiche sans geste (Firefox peut la présenter en mode discret). Pour Safari iOS, le comportement n'a pas pu être vérifié : le correctif ajoute donc le bandeau « Activer ma position » si aucune réponse n'arrive en 10 s.

États de permission vus par l'utilisateur, avant correctif : prompt = invite une seule fois dans la vie du navigateur ; granted = position silencieuse ; denied = rien (échec silencieux).

## Correctif (branche `fix-geolocalisation-auto`, depuis `main`)
- `geoloc_auto.js` : plus de drapeau « déjà demandée ». prompt → appel immédiat (timeout 10 s) ; granted → lecture sans invite ; denied → bandeau d'aide ; pas d'API Permissions ou pas de réponse en 10 s → bandeau d'invitation ; refus explicite mémorisé 7 jours (`declic:geoloc-refus`, try/catch). Exporte `demander()`, utilisé par « Me localiser », « À proximité » et « Activer ma position » (une seule logique, une seule invite).
- `bandeau_position.js` + `shared/_bandeau_position` + `bandeau_position.css` : bandeau fermable (accueil, /labo/opportunites, /labo/belles-histoires, /labo/diorama).
- `diorama_controller` : « Me localiser » passe par `demander()` ; accueil : pastilles « Plus proches » (actif d'office dès que la position est connue) et « À proximité » (≤ 10 km) dans le volet.
- `explorateur_controller` : « À proximité » passe par `demander()` ; tri « Plus proches » appliqué d'office à la première position.
- `/labo/diorama` : charge `geoloc_auto`, recentre sur la position (si elle est dans le secteur couvert).
- Tests : `test/system/geoloc_auto_test.rb` (7 tests).

Résultats : `bin/rails test` 119 verts ; système 28 verts sur 29. Le test en échec, `calques_test.rb:112` (« le style du diorama se garde… »), échoue à l'identique sur `main` sans mes changements (tuiles Leaflet non chargées) : sans rapport.
