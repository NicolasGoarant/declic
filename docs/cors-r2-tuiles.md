# CORS des tuiles du diorama (Cloudflare R2) — relevé du 14/10/2026

Tuiles : `https://tuiles-declic.mist-media.eu/{style}/{z}/{x}/{y}.webp` (styles `jeu-video-v2`, `toits-v1`), manifestes `…/{dossier}/manifeste.json` (modèle dans `app/models/diorama_tuiles.rb`).

## Relevé (curl avec en-tête `Origin`, sur une tuile existante)
| Origine | Access-Control-Allow-Origin | Verdict |
|---|---|---|
| https://www.declic.site | https://www.declic.site | autorisée |
| https://declic.site | https://declic.site | autorisée |
| http://localhost:3000 | http://localhost:3000 | autorisée |
| http://localhost:3003 | http://localhost:3003 | autorisée |
| http://127.0.0.1:3003 | (aucun en-tête) | **refusée** |

Pré-requête OPTIONS depuis `http://127.0.0.1:3003` : HTTP 403.

## Cause de « Le diorama n'a pas pu se charger : voici le plan »
Sur `http://127.0.0.1:3003`, le navigateur bloque les `fetch` des manifestes : *« Access to fetch at 'https://tuiles-declic.mist-media.eu/jeu-video-v2/manifeste.json' from origin 'http://127.0.0.1:3003' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present »* (`diorama_controller.js`, `catch` de `demarrer`, message via `alerter`). Pour un navigateur, `127.0.0.1` et `localhost` sont deux origines différentes : seule `localhost` est dans la politique. Sur `http://localhost:3003`, le diorama se charge (testé : aucune alerte).

**Solution immédiate, sans toucher à Cloudflare : ouvrir `http://localhost:3003`.**

## Option : autoriser aussi 127.0.0.1:3003
Cloudflare → R2 → bucket des tuiles → Settings → CORS Policy → Edit/Add CORS policy → onglet JSON, coller :

```json
[{"AllowedOrigins": ["https://www.declic.site", "https://declic.site", "http://localhost:3000", "http://localhost:3003", "http://127.0.0.1:3003"], "AllowedMethods": ["GET", "HEAD"], "AllowedHeaders": ["*"], "MaxAgeSeconds": 3600}]
```
(`http://localhost:3000` est gardé : il est déjà autorisé et sert aux tests.) Puis Save. Vérifier :
`curl -s -D - -o /dev/null -H "Origin: http://127.0.0.1:3003" https://tuiles-declic.mist-media.eu/jeu-video-v2/0/0/0.webp | grep -i access-control`

`wrangler` n'est pas installé sur cette machine : rien n'a été exécuté côté Cloudflare.
