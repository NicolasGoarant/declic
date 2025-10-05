/* global L */
/**
 * Geo follow robuste pour Leaflet + Turbo/Stimulus + iOS Safari.
 * - Démarre automatiquement (poll + hook sur L.map + fallback sur 1er tap).
 * - Point bleu uniquement (pas de cercle de précision).
 * - watchPosition avec maximumAge: 0 + "poke" périodique iOS.
 * - Pause/reprise sur changement de visibilité.
 * - Bascule "📍 Suivre / 📍 Libre" avec auto-stop si l'utilisateur manipule la carte.
 *
 * Debug: localStorage.declicGeoDebug = "1"
 */
(() => {
  const DBG = !!localStorage.declicGeoDebug;
  const log = (...a) => DBG && console.log('[declic-geo]', ...a);

  // ------------------------ State global ------------------------
  const STATE = {
    started: false,
    map: null,
    stopWatch: null,
    stopFollowCtl: null,
    bootTries: 0,
  };

  // ---------------------- Helpers génériques --------------------
  const throttle = (fn, delay) => {
    let t = 0;
    return (...a) => {
      const now = Date.now();
      if (now - t >= delay) {
        t = now;
        fn(...a);
      }
    };
  };

  const getMapCandidate = () =>
    (window.DeclicMap && window.DeclicMap.map) ||
    window.map ||
    window.__leafletMap ||
    null;

  const ensureSecureContext = () => {
    if (!window.isSecureContext) {
      console.warn('Geolocation requiert HTTPS (secure context).');
      return false;
    }
    return true;
  };

  // Distance en mètres (Haversine), utile pour ignorer les tremblements < n m
  const distMeters = (a, b) => {
    if (!a || !b) return Infinity;
    const toRad = (x) => (x * Math.PI) / 180;
    const R = 6371000;
    const dLat = toRad(b.lat - a.lat);
    const dLng = toRad(b.lng - a.lng);
    const s1 =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(a.lat)) *
        Math.cos(toRad(b.lat)) *
        Math.sin(dLng / 2) ** 2;
    return 2 * R * Math.atan2(Math.sqrt(s1), Math.sqrt(1 - s1));
  };

  // ---------------------- Suivi GPS continu ---------------------
  // opts: { follow:boolean, highAccuracy:boolean, minMove:number, staleRefreshMs:number }
  function startGeoWatch(map, opts) {
    if (!('geolocation' in navigator)) {
      console.warn('Geolocation non disponible');
      return () => {};
    }
    const cfg = Object.assign(
      {
        follow: true,
        highAccuracy: true,
        minMove: 2,            // ignore mouvements < 2m
        staleRefreshMs: 15000, // coup de "poke" iOS si ça se fige
        timeoutMs: 20000,
      },
      opts || {},
    );

    let marker = null;
    let last = null;
    let alive = true;

    const panSmooth = throttle((ll) => {
      try {
        map.panTo(ll, { animate: true, duration: 0.6 });
      } catch {}
    }, 700);

    const blueDot = () =>
      L.divIcon({
        className: '',
        html:
          '<div style="width:14px;height:14px;border-radius:9999px;background:#2563eb;border:2px solid #fff;box-shadow:0 0 0 4px rgba(37,99,235,.25)"></div>',
        iconSize: [14, 14],
        iconAnchor: [7, 7],
      });

    const onPos = (pos) => {
      if (!alive) return;
      const c = pos && pos.coords;
      if (!c) return;

      const next = { lat: c.latitude, lng: c.longitude };
      if (typeof next.lat !== 'number' || typeof next.lng !== 'number') return;

      // Filtre anti-tremblements
      if (last && distMeters(last, next) < cfg.minMove) {
        // on garde quand même la MAJ marker + pan (pour fluidité au pas)
      }

      if (!marker) {
        marker = L.marker([next.lat, next.lng], {
          icon: blueDot(),
          zIndexOffset: 1000,
          interactive: false,
        }).addTo(map);
        // Premier fix => centre
        const z = map.getZoom();
        map.setView([next.lat, next.lng], z || 15, { animate: true });
      } else {
        marker.setLatLng([next.lat, next.lng]);
      }

      if (cfg.follow) panSmooth([next.lat, next.lng]);

      last = next;
      window.DeclicMap = window.DeclicMap || {};
      window.DeclicMap.lastUserPosition = { ...next };
    };

    const onErr = (err) =>
      console.warn('Geolocation error:', (err && err.message) || err);

    // important pour iOS : maximumAge: 0 (= aucune position mise en cache)
    const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
      enableHighAccuracy: !!cfg.highAccuracy,
      maximumAge: 0,
      timeout: cfg.timeoutMs,
    });

    // Garde-fou iOS : ping régulier pour "réveiller" le provider si figé
    const pokeTimer = setInterval(() => {
      if (!alive) return;
      navigator.geolocation.getCurrentPosition(onPos, onErr, {
        enableHighAccuracy: !!cfg.highAccuracy,
        maximumAge: 0,
        timeout: cfg.timeoutMs,
      });
    }, cfg.staleRefreshMs);

    function stop() {
      alive = false;
      try {
        navigator.geolocation.clearWatch(watchId);
      } catch {}
      clearInterval(pokeTimer);
      // On laisse le point visible (plus lisible). Pour l’enlever :
      // if (marker) { map.removeLayer(marker); marker = null; }
    }

    window.addEventListener('beforeunload', stop, { once: true });
    return stop;
  }

  // ----------------- Contrôle "📍 Suivre / 📍 Libre" -----------------
  function addFollowControl(map, startFn) {
    const ctl = L.control({ position: 'topleft' });
    let following = true;
    let stopFn = null;
    let btn = null;

    const refreshLabel = () => {
      if (btn) btn.textContent = following ? '📍 Suivre' : '📍 Libre';
    };

    ctl.onAdd = () => {
      btn = L.DomUtil.create('button');
      btn.type = 'button';
      btn.title = 'Activer/désactiver le suivi de ma position';
      btn.style.cssText =
        'background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:6px 10px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.15);';
      refreshLabel();

      L.DomEvent.on(btn, 'click', (e) => {
        L.DomEvent.stopPropagation(e);
        following = !following;
        refreshLabel();
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

    if (typeof startFn === 'function') stopFn = startFn({ follow: true });

    // Si l’utilisateur manipule la carte, couper le suivi
    const autoStop = () => {
      if (!following) return;
      following = false;
      refreshLabel();
      if (stopFn) {
        stopFn();
        stopFn = null;
      }
    };
    map.on('dragstart zoomstart', autoStop);

    return () => {
      try {
        if (stopFn) stopFn();
        map.off('dragstart zoomstart', autoStop);
        ctl.remove();
      } catch {}
    };
  }

  // -------------------------- Bootstrap robuste -----------------------
  function tryBoot() {
    if (!ensureSecureContext()) return;
    if (STATE.started) return;

    // Récupère une carte éventuelle
    let map = getMapCandidate();

    // Si indisponible, on hooke la fabrique L.map pour capter la création
    if (!map && window.L && typeof L.map === 'function' && !L.map.__declicPatched) {
      const origLMap = L.map;
      L.map = function patchedLMap(...args) {
        const m = origLMap.apply(this, args);
        try {
          window.__leafletMap = m; // exposer une porte de secours
          window.dispatchEvent(new CustomEvent('declic:map_ready', { detail: { map: m } }));
        } catch {}
        return m;
      };
      L.map.__declicPatched = true;
      log('Patch L.map appliqué');
    }

    // Si toujours pas de carte, on planifie des essais (poll léger)
    if (!map) {
      STATE.bootTries += 1;
      if (STATE.bootTries < 50) {
        setTimeout(tryBoot, 200); // ~10s au total
      } else {
        log('Map introuvable après polling, attente d’un tap utilisateur');
      }
      return;
    }

    // Carte trouvée, on installe
    STATE.map = map;
    STATE.started = true;

    STATE.stopFollowCtl = addFollowControl(map, (opts) => {
      if (STATE.stopWatch) STATE.stopWatch();
      STATE.stopWatch = startGeoWatch(map, Object.assign({ follow: true }, opts));
      return () => {
        if (STATE.stopWatch) {
          STATE.stopWatch();
          STATE.stopWatch = null;
        }
      };
    });

    // Pause/reprise quand l’onglet est masqué
    document.addEventListener('visibilitychange', () => {
      if (!STATE.started) return;
      if (document.hidden) {
        if (STATE.stopWatch) {
          STATE.stopWatch();
          STATE.stopWatch = null;
        }
      } else {
        const m = STATE.map || getMapCandidate();
        if (m && !STATE.stopWatch) {
          STATE.stopWatch = startGeoWatch(m, { follow: true });
        }
      }
    });

    log('Déclic Geo démarré');
  }

  // Événements Turbo / DOM
  document.addEventListener('turbo:load', tryBoot);
  document.addEventListener('DOMContentLoaded', tryBoot);
  window.addEventListener('pageshow', tryBoot);
  window.addEventListener('declic:map_ready', tryBoot);

  // Fallback iOS : si rien n’a démarré au bout de 2s, retenter au 1er tap
  setTimeout(() => {
    if (!STATE.started) {
      const oneTap = () => {
        tryBoot();
        window.removeEventListener('touchstart', oneTap, true);
        window.removeEventListener('click', oneTap, true);
      };
      window.addEventListener('touchstart', oneTap, true);
      window.addEventListener('click', oneTap, true);
      log('En attente d’un premier tap pour lancer le suivi');
    }
  }, 2000);

  // Expose debug minimal
  window.DeclicGeo = {
    boot: tryBoot,
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
