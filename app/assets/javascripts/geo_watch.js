/* global L */

/**
 * Petit utilitaire: appeler cb quand window.map est prêt.
 * - Essaie sur DOMContentLoaded, turbo:load et pageshow
 * - Si la carte n'est pas encore là, on attend via un polling très léger.
 */
function whenMapReady(cb) {
  const tryOnce = () => {
    if (window.map && typeof window.map.addLayer === 'function') {
      cb(window.map);
      return true;
    }
    return false;
  };

  if (tryOnce()) return;

  const tick = setInterval(() => {
    if (tryOnce()) clearInterval(tick);
  }, 60);

  const onLoad = () => tryOnce();
  document.addEventListener('turbo:load', onLoad, { once: true });
  document.addEventListener('DOMContentLoaded', onLoad, { once: true });
  window.addEventListener('pageshow', onLoad, { once: true });
}

/**
 * Supprime tout marker "étranger" qui serait posé près d'un point (ex: pin rouge par un autre script).
 * On garde seulement notre marker (identifié par data-user-dot="1").
 */
function pruneStrayMarkers(map, latlng, keepEl) {
  const maxMeters = 60; // on considère “proche” si < 60 m
  map.eachLayer((layer) => {
    if (!(layer instanceof L.Marker)) return;

    // notre marker à garder ?
    const el = layer.getElement && layer.getElement();
    if (el && el.getAttribute && el.getAttribute('data-user-dot') === '1') return;
    if (keepEl && el === keepEl) return;

    // opportunités : souvent avec une icône custom (divIcon avec autre HTML ou className spécifique)
    // On ne supprime que les markers quasi au même endroit que l'utilisateur
    try {
      const p = layer.getLatLng && layer.getLatLng();
      if (!p) return;
      const d = map.distance([p.lat, p.lng], latlng);
      if (d <= maxMeters) map.removeLayer(layer);
    } catch (_) {}
  });
}

/**
 * Démarre un watchPosition et crée un unique marker “point bleu” qui suit l’utilisateur.
 * Pas de cercle d’accuracy.
 * Retourne un stop().
 */
function startGeoWatch(map, opts) {
  if (!('geolocation' in navigator) || !map) {
    console.warn('Geolocation non dispo ou map manquante');
    return function () {};
  }

  const cfg = Object.assign(
    {
      follow: true,
      maxAgeMs: 10000,
      highAccuracy: true
    },
    opts || {}
  );

  let marker = null;
  let lastPan = 0;

  const makeUserIcon = () =>
    L.divIcon({
      className: '',
      html:
        '<div data-user-dot="1" style="width:16px;height:16px;border-radius:50%;background:#2563eb;border:2px solid #fff;box-shadow:0 0 0 6px rgba(37,99,235,.22);"></div>',
      iconSize: [16, 16],
      iconAnchor: [8, 8]
    });

  const onPos = (pos) => {
    const c = pos && pos.coords;
    const lat = c && typeof c.latitude === 'number' ? c.latitude : null;
    const lng = c && typeof c.longitude === 'number' ? c.longitude : null;
    if (lat == null || lng == null) return;

    const here = [lat, lng];

    if (!marker) {
      marker = L.marker(here, { icon: makeUserIcon(), interactive: false }).addTo(map);
      // Nettoie tout marker parasite proche (ex: pin rouge posé par un autre script)
      const el = marker.getElement && marker.getElement();
      if (el) el.setAttribute('data-user-dot', '1');
      pruneStrayMarkers(map, { lat, lng }, el);
    } else {
      marker.setLatLng(here);
      pruneStrayMarkers(map, { lat, lng }, marker.getElement && marker.getElement());
    }

    if (cfg.follow) {
      const now = Date.now();
      if (now - lastPan > 700) {
        map.panTo(here, { animate: true, duration: 0.6 });
        lastPan = now;
      }
    }
  };

  const onErr = (err) => console.warn('Geolocation error:', err && err.message ? err.message : err);

  const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
    enableHighAccuracy: !!cfg.highAccuracy,
    maximumAge: cfg.maxAgeMs,
    timeout: 10000
  });

  const stop = () => {
    try {
      navigator.geolocation.clearWatch(watchId);
    } catch (_) {}
  };
  window.addEventListener('beforeunload', stop, { once: true });
  return stop;
}

/**
 * Petit bouton “📍 Suivre / Libre” (optionnel)
 * Si tu ne le veux pas, commente l’appel à addFollowControl plus bas.
 */
function addFollowControl(map, startFn) {
  const ctl = L.control({ position: 'topleft' });
  let following = true;
  let stopFn = null;
  let _btn = null;

  ctl.onAdd = function () {
    const btn = L.DomUtil.create('button');
    _btn = btn;
    btn.type = 'button';
    btn.textContent = '📍 Suivre';
    btn.title = 'Activer/désactiver le suivi de ma position';
    btn.style.cssText =
      'background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:6px 10px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.15);';
    L.DomEvent.on(btn, 'click', function (e) {
      L.DomEvent.stopPropagation(e);
      following = !following;
      btn.textContent = following ? '📍 Suivre' : '📍 Libre';
      if (stopFn) {
        stopFn();
        stopFn = null;
      }
      if (following && typeof startFn === 'function') {
        stopFn = startFn({ follow: true });
      }
    });
    return btn;
  };

  ctl.addTo(map);

  // démarre en mode “suivre”
  if (typeof startFn === 'function') stopFn = startFn({ follow: true });

  // coupe le follow si l'utilisateur manipule la carte
  const autoStopFollow = function () {
    if (!following) return;
    following = false;
    if (_btn) _btn.textContent = '📍 Libre';
    if (stopFn) {
      stopFn();
      stopFn = null;
    }
  };
  map.on('dragstart zoomstart', autoStopFollow);

  return function () {
    if (stopFn) stopFn();
    map.off('dragstart zoomstart', autoStopFollow);
  };
}

/* ======== Lancer automatiquement dès que la carte est prête ======== */
whenMapReady((map) => {
  // 1) démarre le suivi immédiatement
  startGeoWatch(map, { follow: true });

  // 2) (optionnel) ajoute le bouton suivre/libre
  addFollowControl(map, (opts) => startGeoWatch(map, opts));
});



