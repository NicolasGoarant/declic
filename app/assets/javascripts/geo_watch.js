/* global L */
/*
 * GeoWatch — Déclic
 * ----------------------------------------------
 * - Un unique point BLEU qui suit l'utilisateur.
 * - AUCUN pin rouge, AUCUN halo d'accuracy par défaut.
 * - Démarrage/arrêt propre, idempotent (peut être appelé plusieurs fois).
 * - "Follow" actif au démarrage ; se désactive si l'utilisateur manipule la carte.
 * - Supprime tout contrôle Leaflet non lié au zoom (évite l'icône carré avec pin rouge).
 * - Exposé sous window.DeclicGeo : start(map, opts), stop(), isRunning(), setFollow(bool)
 *
 *  opts (tous facultatifs) :
 *    - follow: true        // recadre automatiquement la carte
 *    - showAccuracy: false // si true, affiche un cercle d'accuracy (désactivé selon demande)
 *    - highAccuracy: true
 *    - maxAgeMs: 15000
 *    - panIntervalMs: 800  // délai min entre recadrages
 *    - firstFitZoom: null  // si nombre, fait map.setView([lat,lng], firstFitZoom) au 1er fix
 */

(function () {
  // Ne crée l'objet global qu'une seule fois
  if (window.DeclicGeo && window.DeclicGeo.__ready) return;

  const state = {
    map: null,
    watchId: null,
    marker: null,
    accCircle: null,
    following: true,
    lastPanAt: 0,
    opts: null,
    boundAutoStopFollow: null
  };

  const DEFAULTS = {
    follow: true,
    showAccuracy: false,
    highAccuracy: true,
    maxAgeMs: 15000,
    panIntervalMs: 800,
    firstFitZoom: null
  };

  function ensureMapOk(map) {
    return !!(map && typeof map.on === 'function' && map._loaded !== undefined);
  }

  function removeNonZoomControls(map) {
    try {
      const root = map.getContainer().querySelector('.leaflet-top.leaflet-left');
      if (!root) return;
      Array.from(root.children).forEach(el => {
        const isZoom = el.classList.contains('leaflet-control-zoom');
        if (!isZoom) el.remove();
      });
    } catch (_) { /* no-op */ }
  }

  function blueDotIcon() {
    // petit point bleu (comme iOS) : cercle bleu avec bordure blanche et léger ring
    const html =
      '<div style="' +
      'width:18px;height:18px;border-radius:9999px;' +
      'background:#2563eb;border:2px solid #fff;' +
      'box-shadow:0 0 0 3px rgba(37,99,235,.35);' +
      '"></div>';
    return L.divIcon({
      className: '',
      html: html,
      iconSize: [18, 18],
      iconAnchor: [9, 9]
    });
  }

  function onPosition(pos) {
    if (!state.map || !pos || !pos.coords) return;

    const { latitude, longitude, accuracy } = pos.coords;
    if (typeof latitude !== 'number' || typeof longitude !== 'number') return;

    // Crée/maj du point bleu
    if (!state.marker) {
      state.marker = L.marker([latitude, longitude], { icon: blueDotIcon() }).addTo(state.map);
      // 1er fix : on centre immédiatement
      if (state.opts.firstFitZoom && Number.isFinite(state.opts.firstFitZoom)) {
        state.map.setView([latitude, longitude], Number(state.opts.firstFitZoom), { animate: true });
      } else if (state.opts.follow) {
        state.map.panTo([latitude, longitude], { animate: true });
      }
    } else {
      state.marker.setLatLng([latitude, longitude]);
    }

    // Accuracy (désactivé par défaut)
    if (state.opts.showAccuracy) {
      const r = Math.max(5, Math.min(accuracy || 0, 1000));
      if (!state.accCircle) {
        state.accCircle = L.circle([latitude, longitude], {
          radius: r,
          color: '#2563eb',
          weight: 1,
          fillColor: '#60a5fa',
          fillOpacity: 0.18
        }).addTo(state.map);
      } else {
        state.accCircle.setLatLng([latitude, longitude]).setRadius(r);
      }
    }

    // Follow
    if (state.following) {
      const now = Date.now();
      if (now - state.lastPanAt > state.opts.panIntervalMs) {
        state.map.panTo([latitude, longitude], { animate: true });
        state.lastPanAt = now;
      }
    }
  }

  function onError(err) {
    // Pas d'alertes intrusives : on log juste
    console.warn('Geolocation error:', err && err.message ? err.message : err);
  }

  function bindAutoStopFollow() {
    if (!state.map) return;
    if (state.boundAutoStopFollow) return;

    const handler = function () {
      if (!state.following) return;
      state.following = false;
    };
    state.boundAutoStopFollow = handler;
    state.map.on('dragstart zoomstart', handler);
  }

  function unbindAutoStopFollow() {
    if (!state.map || !state.boundAutoStopFollow) return;
    state.map.off('dragstart zoomstart', state.boundAutoStopFollow);
    state.boundAutoStopFollow = null;
  }

  function start(map, opts) {
    if (!ensureMapOk(map)) {
      console.warn('[DeclicGeo] Carte Leaflet manquante ou invalide.');
      return () => {};
    }

    // Si déjà en cours, on stoppe proprement avant de relancer
    if (state.watchId !== null) stop();

    state.map = map;
    state.opts = Object.assign({}, DEFAULTS, opts || {});
    state.following = !!state.opts.follow;
    state.lastPanAt = 0;

    // Nettoie d'éventuels contrôles non-zoom restants
    removeNonZoomControls(map);

    // Lance le watch
    try {
      state.watchId = navigator.geolocation.watchPosition(onPosition, onError, {
        enableHighAccuracy: !!state.opts.highAccuracy,
        maximumAge: state.opts.maxAgeMs,
        timeout: 10000
      });
    } catch (e) {
      console.warn('[DeclicGeo] Geolocation non disponible sur ce navigateur.', e);
      state.watchId = null;
    }

    // Un "nudge" au retour d'onglet (iOS/Android parfois gèlent le watch)
    const onVisible = () => {
      if (document.visibilityState === 'visible' && navigator.geolocation && navigator.geolocation.getCurrentPosition) {
        navigator.geolocation.getCurrentPosition(onPosition, onError, {
          enableHighAccuracy: !!state.opts.highAccuracy,
          maximumAge: state.opts.maxAgeMs,
          timeout: 8000
        });
      }
    };
    document.addEventListener('visibilitychange', onVisible, { passive: true });

    // Sécurité : arrêter le watch à la fermeture
    const stopOnUnload = () => stop();
    window.addEventListener('beforeunload', stopOnUnload, { once: true });

    // Mémorise pour stop()
    state._cleanup = () => {
      document.removeEventListener('visibilitychange', onVisible);
      window.removeEventListener('beforeunload', stopOnUnload);
    };

    // Désactive follow dès que l'utilisateur manipule la carte
    bindAutoStopFollow();

    return stop;
  }

  function stop() {
    // Arrête geolocation
    try {
      if (state.watchId !== null) navigator.geolocation.clearWatch(state.watchId);
    } catch (_) { /* no-op */ }
    state.watchId = null;

    // Nettoie couche/marker/accuracy
    try {
      if (state.marker) { state.marker.remove(); }
      if (state.accCircle) { state.accCircle.remove(); }
    } catch (_) { /* no-op */ }
    state.marker = null;
    state.accCircle = null;

    // Nettoie events
    unbindAutoStopFollow();
    if (state._cleanup) { try { state._cleanup(); } catch (_) {} }
    state._cleanup = null;

    // Ne touche pas à la map (laisse les autres couches)
  }

  function isRunning() {
    return state.watchId !== null;
  }

  function setFollow(on) {
    state.following = !!on;
  }

  // API publique
  window.DeclicGeo = {
    startGeoWatch: start,
    stopGeoWatch: stop,
    isRunning: isRunning,
    setFollow: setFollow,
    __ready: true
  };
})();




