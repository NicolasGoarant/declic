/* global L */

// Démarre un suivi GPS continu. Retourne une fonction stop().
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

  const onPos = (pos) => {
    const c = pos.coords || {};
    const lat = c.latitude;
    const lng = c.longitude;
    if (typeof lat !== 'number' || typeof lng !== 'number') return;

    // 🔵 Crée ou met à jour le marker bleu simple
    if (!marker) {
      marker = L.marker([lat, lng], {
        icon: L.divIcon({
          className: '',
          html: `
            <div style="
              width:16px;
              height:16px;
              border-radius:50%;
              background:#2563eb;
              box-shadow:0 0 0 6px rgba(37,99,235,0.2);
              border:2px solid #fff;
            "></div>`,
          iconSize: [16, 16],
          iconAnchor: [8, 8]
        })
      }).addTo(map);
    } else {
      marker.setLatLng([lat, lng]);
    }

    // 🔁 Suit la position automatiquement
    if (cfg.follow) {
      const now = Date.now();
      if (now - lastPan > 800) {
        map.panTo([lat, lng], { animate: true, duration: 0.6 });
        lastPan = now;
      }
    }
  };

  const onErr = (err) => console.warn('Geolocation error:', err?.message || err);

  const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
    enableHighAccuracy: !!cfg.highAccuracy,
    maximumAge: cfg.maxAgeMs,
    timeout: 10000
  });

  const stop = () => {
    try {
      navigator.geolocation.clearWatch(watchId);
    } catch (e) {}
  };
  window.addEventListener('beforeunload', stop, { once: true });
  return stop;
}

// Bouton Leaflet pour activer/désactiver l'autocentrage
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

  // ✅ Lance automatiquement le suivi dès que la carte est prête
  if (typeof startFn === 'function') {
    stopFn = startFn({ follow: true });
  }

  // 🛑 Stoppe le suivi si l’utilisateur manipule la carte
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

// ✅ Et surtout : exécuter ce script dès que la carte est prête
document.addEventListener('DOMContentLoaded', () => {
  if (window.map) {
    addFollowControl(window.map, (opts) => startGeoWatch(window.map, opts));
  } else {
    console.warn('⚠️ window.map non trouvé — assure-toi de l’exposer globalement');
  }
});


