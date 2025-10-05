/* global L */
(() => {
  // ========================= Utils & état global =========================
  const STATE = {
    started: false,
    stopWatch: null,
    stopFollowCtl: null,
  };

  const getMap = () =>
    (window.DeclicMap && window.DeclicMap.map) ||
    window.map ||
    window.__leafletMap ||
    null;

  // Petite aide pour throttle (panTo)
  const throttle = (fn, delay) => {
    let last = 0;
    return (...args) => {
      const now = Date.now();
      if (now - last >= delay) {
        last = now;
        fn(...args);
      }
    };
  };

  // ========================= Suivi GPS continu ==========================
  // opts: { follow:boolean, accuracy:boolean, maxAgeMs:number, highAccuracy:boolean }
  function startGeoWatch(map, opts) {
    if (!('geolocation' in navigator) || !map) {
      console.warn('Geolocation non dispo ou map manquante');
      return () => {};
    }

    const cfg = Object.assign(
      {
        follow: true,
        accuracy: true,
        maxAgeMs: 10_000,
        highAccuracy: true,
      },
      opts || {},
    );

    let marker = null;
    let circle = null;

    const safePan = throttle((latlng) => {
      try {
        map.panTo(latlng, { animate: true, duration: 0.6 });
      } catch (_) {}
    }, 800);

    const onPos = (pos) => {
      const c = (pos && pos.coords) || {};
      const lat = typeof c.latitude === 'number' ? c.latitude : null;
      const lng = typeof c.longitude === 'number' ? c.longitude : null;
      const acc = typeof c.accuracy === 'number' ? c.accuracy : null;
      if (lat === null || lng === null) return;

      const latlng = [lat, lng];

      if (!marker) {
        marker = L.marker(latlng, {
          icon: L.divIcon({
            className: '',
            html:
              '<div style="width:18px;height:18px;border-radius:9999px;background:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.35);border:2px solid #fff;"></div>',
            iconSize: [18, 18],
            iconAnchor: [9, 9],
          }),
        }).addTo(map);
      } else {
        marker.setLatLng(latlng);
      }

      if (cfg.accuracy) {
        const r = Math.max(10, Math.min(acc || 0, 400));
        if (!circle) {
          circle = L.circle(latlng, {
            radius: r,
            color: '#2563eb',
            weight: 1,
            fillColor: '#60a5fa',
            fillOpacity: 0.2,
          }).addTo(map);
        } else {
          circle.setLatLng(latlng).setRadius(r);
        }
      }

      if (cfg.follow) safePan(latlng);

      // Optionnel : exposer la dernière position à d’autres scripts
      window.DeclicMap = window.DeclicMap || {};
      window.DeclicMap.lastUserPosition = { lat, lng, accuracy: acc };
      if (typeof window.DeclicMap.updateUserPosition === 'function') {
        try {
          window.DeclicMap.updateUserPosition(latlng, acc);
        } catch (_) {}
      }
    };

    const onErr = (err) =>
      console.warn('Geolocation error:', (err && err.message) || err);

    const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
      enableHighAccuracy: !!cfg.highAccuracy,
      maximumAge: cfg.maxAgeMs,
      timeout: 10_000,
    });

    const cleanupBeforeUnload = () => stop();

    function stop() {
      try {
        navigator.geolocation.clearWatch(watchId);
      } catch (_) {}
      try {
        window.removeEventListener('beforeunload', cleanupBeforeUnload, {
          once: true,
        });
      } catch (_) {}
      try {
        if (marker) {
          map.removeLayer(marker);
          marker = null;
        }
        if (circle) {
          map.removeLayer(circle);
          circle = null;
        }
      } catch (_) {}
    }

    window.addEventListener('beforeunload', cleanupBeforeUnload, { once: true });
    return stop;
  }

  // =================== Contrôle Leaflet Suivre / Libre ===================
  // Ajoute un bouton pour activer/désactiver le "follow".
  function addFollowControl(map, startFn) {
    const ctl = L.control({ position: 'topleft' });
    let following = true;
    let stopFn = null;
    let btnEl = null;

    const setBtnState = () => {
      if (!btnEl) return;
      btnEl.textContent = following ? '📍 Suivre' : '📍 Libre';
    };

    ctl.onAdd = function () {
      const btn = L.DomUtil.create('button');
      btnEl = btn;
      btn.type = 'button';
      btn.title = 'Activer/désactiver le suivi de ma position';
      btn.style.cssText =
        'background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:6px 10px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.15);';
      setBtnState();

      L.DomEvent.on(btn, 'click', (e) => {
        L.DomEvent.stopPropagation(e);
        following = !following;
        setBtnState();

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

    // Démarre par défaut en "suivre"
    if (typeof startFn === 'function') {
      stopFn = startFn({ follow: true });
    }

    // Si l'utilisateur manipule la carte, on bascule en "Libre"
    const autoStopFollow = () => {
      if (!following) return;
      following = false;
      setBtnState();
      if (stopFn) {
        stopFn();
        stopFn = null;
      }
    };
    map.on('dragstart zoomstart', autoStopFollow);

    // Nettoyage
    return function destroy() {
      try {
        if (stopFn) stopFn();
        map.off('dragstart zoomstart', autoStopFollow);
        ctl.remove();
      } catch (_) {}
    };
  }

  // ====================== Bootstrap auto & idempotent =====================
  function bootOnce() {
    if (STATE.started) return;
    const map = getMap();
    if (!map) return; // on réessaiera au prochain événement (Turbo/pageshow)

    // Empêche les doubles inits
    STATE.started = true;

    // Ajoute le contrôle et démarre le suivi
    STATE.stopFollowCtl = addFollowControl(map, (opts) => {
      if (STATE.stopWatch) STATE.stopWatch(); // safety
      STATE.stopWatch = startGeoWatch(map, Object.assign({ follow: true }, opts));
      return () => {
        if (STATE.stopWatch) {
          STATE.stopWatch();
          STATE.stopWatch = null;
        }
      };
    });

    // Pause quand l’onglet est caché, reprise quand visible
    document.addEventListener('visibilitychange', () => {
      if (!STATE.started) return;
      if (document.hidden) {
        if (STATE.stopWatch) {
          STATE.stopWatch();
          STATE.stopWatch = null;
        }
      } else {
        const m = getMap();
        if (m && !STATE.stopWatch) {
          STATE.stopWatch = startGeoWatch(m, { follow: true });
        }
      }
    });
  }

  // Écoute tous les cas de figure (Turbo + premier chargement + back/forward cache)
  document.addEventListener('turbo:load', bootOnce);
  document.addEventListener('DOMContentLoaded', bootOnce);
  window.addEventListener('pageshow', bootOnce);

  // Expose (optionnel) pour debug manuel
  window.DeclicGeo = {
    boot: bootOnce,
    stopAll() {
      try {
        if (STATE.stopWatch) STATE.stopWatch();
        if (STATE.stopFollowCtl) STATE.stopFollowCtl();
      } finally {
        STATE.started = false;
        STATE.stopWatch = null;
        STATE.stopFollowCtl = null;
      }
    },
  };
})();
