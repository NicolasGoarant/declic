// sw.js — Déclic Service Worker
// Stratégie :
//   - Assets statiques (CSS, JS, fonts, images) → Cache First
//   - Pages HTML                                 → Network First (fallback offline page)
//   - API JSON                                   → Network Only (pas de cache pour les données)

const CACHE_VERSION = 'declic-v1';
const STATIC_CACHE  = `${CACHE_VERSION}-static`;
const PAGES_CACHE   = `${CACHE_VERSION}-pages`;

// Assets à précacher au moment de l'installation
const PRECACHE_ASSETS = [
  '/',
  '/explorer',
  '/offline',
  // Leaflet (CDN) — optionnel, peut être retiré si tu ne veux pas précacher le CDN
  // 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  // 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
];

// ─────────────────────────────────────────────
// INSTALL — précache les assets essentiels
// ─────────────────────────────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        // Ne pas faire planter l'installation si une ressource est indisponible
        console.warn('[SW] Précache partiel :', err);
      });
    }).then(() => self.skipWaiting())
  );
});

// ─────────────────────────────────────────────
// ACTIVATE — nettoie les anciens caches
// ─────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key.startsWith('declic-') && key !== STATIC_CACHE && key !== PAGES_CACHE)
          .map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

// ─────────────────────────────────────────────
// FETCH — logique de cache selon le type
// ─────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // 1. Ignore les requêtes non-GET et les requêtes admin
  if (request.method !== 'GET') return;
  if (url.pathname.startsWith('/admin')) return;
  if (url.pathname.startsWith('/rails/active_storage')) return;

  // 2. API JSON → Network Only
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(fetch(request));
    return;
  }

  // 3. Assets statiques (CSS, JS, images, fonts) → Cache First
  if (isStaticAsset(url)) {
    event.respondWith(cacheFirst(request, STATIC_CACHE));
    return;
  }

  // 4. Pages HTML → Network First avec fallback
  if (request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(networkFirstWithFallback(request));
    return;
  }

  // 5. Tout le reste → Network First
  event.respondWith(networkFirst(request, PAGES_CACHE));
});

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
function isStaticAsset(url) {
  const ext = url.pathname.split('.').pop().toLowerCase();
  const staticExts = ['css', 'js', 'png', 'jpg', 'jpeg', 'svg', 'webp', 'gif', 'ico', 'woff', 'woff2', 'ttf'];
  return staticExts.includes(ext);
}

async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    console.warn('[SW] Cache first — réseau indisponible :', request.url);
    return new Response('', { status: 503 });
  }
}

async function networkFirst(request, cacheName) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    const cached = await caches.match(request);
    return cached || new Response('', { status: 503 });
  }
}

async function networkFirstWithFallback(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(PAGES_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    const cached = await caches.match(request);
    if (cached) return cached;

    // Fallback : page offline
    const offline = await caches.match('/offline');
    if (offline) return offline;

    return new Response(
      `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Déclic — Hors ligne</title>
  <style>
    body { font-family: system-ui, sans-serif; display: flex; align-items: center;
           justify-content: center; min-height: 100vh; margin: 0; background: #f9fafb; }
    .card { text-align: center; padding: 2rem; max-width: 400px; }
    h1 { color: #7c3aed; font-size: 1.5rem; }
    p  { color: #6b7280; }
    a  { color: #7c3aed; }
  </style>
</head>
<body>
  <div class="card">
    <h1>📡 Déclic est hors ligne</h1>
    <p>Vérifie ta connexion internet, puis <a href="/">réessaie</a>.</p>
  </div>
</body>
</html>`,
      { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
    );
  }
}
