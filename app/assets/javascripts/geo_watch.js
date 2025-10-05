/* global L */

// ------------------------------
// Géoloc continue (un seul point bleu, pas de pin rouge)
// ------------------------------
(function () {
  // état module (évite les doublons quand Turbo/Stimulus rechargent la page)
  let watchId = null;
  let dot = null;       // point bleu
  let ring = null;      // cercle d'imprécision
  let lastPan = 0;
  let cleanupMapHooks = null;

  // crée/maj le point bleu
  function upsertBlueDot(map, lat, lng) {
    if (!dot) {
      dot = L.marker([lat, lng], {
        // point BLEU plein – sans marqueur « pin »
        icon: L.divIcon({
          className: 'declic-blue-dot',
          html:
            '<div style="width:14px;height:14px;border-radius:9999px;background:#2563eb;border:2px solid #fff;box-shadow:0 0 0 4px rgba(37,99,235,.25)"></div>',
          iconSize: [14, 14],
          iconAnchor: [7, 7]
        }),
        interactive: false,
        keyboard: false,
        pane: "markerPane"
      }).addTo(map);
    } else {
      dot.setLatLng([lat, lng]);
    }
  }

  // cercle d’imprécision (souple)
  function upsertAccuracyRing(map, lat, lng, acc) {
    const r = Math.max(10, Math.min(acc || 0, 400));
    if (!ring) {
      ring = L.circle([lat, lng], {
        radius: r,
        color: '#2563eb',
        weight: 1,
        fillColor: '#60a5fa',
        fillOpacity: 0.20
      }).addTo(map);
    } else {
      ring.setLatLng([lat, lng]).setRadius(r);
    }
  }

  // supprime tout contrôle « pin rouge » (boutons ajoutés par d’autres scripts)
  function removeForeignTopLeftControls(map) {
    const topLeft = map && map._controlCorners && map._controlCorners.topleft;
    if (!topLeft) return;
    Array.from(topLeft.children).forEach(el => {
      // on garde UNIQUEMENT le contrôle de zoom natif
      if (!el.classList.contains('leaflet-control-zoom')) el.remove();
    });
  }

  // démarre la watch (1 seule fois)
  function start(map, { follow = true, highAccuracy = true, maxAgeMs = 10000, showAccuracy = true } = {}) {
    if (!map || !('geolocation' in navigator)) return () => {};

    // retire le bouton « pin rouge » éventuel
    removeForeignTopLeftControls(map);

    // s’il existait une watch précédente (navigation Turbo, etc.)
    stop();

    const onPos = (pos) => {
      const c = pos && pos.coords || {};
      const lat = (typeof c.latitude === 'number') ? c.latitude : null;
      const lng = (typeof c.longitude === 'number') ? c.longitude : null;
      const acc = (typeof c.accuracy === 'number') ? c.accuracy : null;
      if (lat == null || lng == null) return;

      upsertBlueDot(map, lat, lng);
      if (showAccuracy) upsertAccuracyRing(map, lat, lng, acc);

      if (follow) {
        const now = Date.now();
        if (now - lastPan > 700) {
          map.panTo([lat, lng], { animate: true, duration: 0.45 });
          lastPan = now;
        }
      }
    };

    const onErr = (err) => {
      // pas de popup, on log seulement
      console.warn('Geolocation error:', err && err.message || err);
    };

    watchId = navigator.geolocation.watchPosition(onPos, onErr, {
      enableHighAccuracy: !!highAccuracy,
      maximumAge: maxAgeMs,
      timeout: 10000
    });

    // si l’utilisateur bouge la carte → on désactive juste l’auto-centrage,
    // MAIS on continue à mettre à jour le point (on ne coupe pas la watch)
    const stopFollow = () => { follow = false; };
    map.on('dragstart zoomstart', stopFollow);

    cleanupMapHooks = () => {
      map.off('dragstart zoomstart', stopFollow);
    };

    // retour: fonction d’arrêt
    return stop;
  }

  function stop() {
    if (watchId != null) {
      try { navigator.geolocation.clearWatch(watchId); } catch(e) {}
      watchId = null;
    }
    if (cleanupMapHooks) { cleanupMapHooks(); cleanupMapHooks = null; }
  }

  // Expose pour ton module « map » (appel explicite depuis ta création de carte)
  window.DeclicGeo = {
    start,
    stop
  };

  // ---------- Auto-init : démarre dès que la map existe ----------
  // 1) si ton script “map” met l’instance sur window.__declicMap
  if (window.__declicMap && typeof window.__declicMap.panTo === 'function') {
    start(window.__declicMap, { follow: true, showAccuracy: true });
  }

  // 2) si ton script émet un event custom quand la map est prête
  document.addEventListener('declic:map-ready', (e) => {
    const map = e && e.detail && e.detail.map;
    if (map) start(map, { follow: true, showAccuracy: true });
  });

  // 3) sécurité : si tu crées la map avant ce fichier,
  //    on tente de l’attraper via un pointeur global courant
  document.addEventListener('turbo:load', () => {
    if (window.__declicMap && typeof window.__declicMap.panTo === 'function') {
      start(window.__declicMap, { follow: true, showAccuracy: true });
    }
  });

  // nettoyage quand on quitte la page
  window.addEventListener('beforeunload', stop, { once: true });
})();



