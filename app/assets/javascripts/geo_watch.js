/* global L */
// ========================== GEO WATCH ==========================
// Démarre un suivi GPS continu. Retourne une fonction stop().
// opts: { follow: boolean, highAccuracy: boolean, maxAgeMs: number }
function startGeoWatch(map, opts){
  if (!('geolocation' in navigator) || !map) {
    console.warn('Geolocation non dispo ou map manquante');
    return function(){};
  }

  const cfg = Object.assign({
    follow: true,
    highAccuracy: true,
    maxAgeMs: 0   // on veut des positions fraîches (iOS)
  }, opts || {});

  let marker = null;
  let lastPan = 0;

  const panIfNeeded = (lat, lng) => {
    if (!cfg.follow) return;
    const now = Date.now();
    if (now - lastPan > 800) {
      try { map.panTo([lat, lng], { animate: true, duration: 0.6 }); } catch(e) {}
      lastPan = now;
    }
  };

  // petit point bleu
  const blueDot = L.divIcon({
    className: '',
    html: '<div style="width:14px;height:14px;border-radius:9999px;background:#2563eb;border:2px solid #fff;box-shadow:0 0 0 4px rgba(37,99,235,.25)"></div>',
    iconSize: [14,14],
    iconAnchor: [7,7]
  });

  const onPos = (pos) => {
    const c = (pos && pos.coords) || {};
    const lat = typeof c.latitude  === 'number' ? c.latitude  : null;
    const lng = typeof c.longitude === 'number' ? c.longitude : null;
    if (lat === null || lng === null) return;

    if (!marker) {
      marker = L.marker([lat, lng], { icon: blueDot, zIndexOffset: 1000, interactive: false }).addTo(map);
      // premier fix : centre
      const z = map.getZoom() || 15;
      try { map.setView([lat, lng], z, { animate: true }); } catch(e) {}
    } else {
      marker.setLatLng([lat, lng]);
    }
    panIfNeeded(lat, lng);
  };

  const onErr = (err) => console.warn('Geolocation error:', (err && err.message) || err);

  // 1) amorce immédiate (utile sur iOS pour « réveiller » le GPS)
  try {
    navigator.geolocation.getCurrentPosition(onPos, onErr, {
      enableHighAccuracy: !!cfg.highAccuracy,
      maximumAge: 0,
      timeout: 10000
    });
  } catch(e) {}

  // 2) suivi continu
  const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
    enableHighAccuracy: !!cfg.highAccuracy,
    maximumAge: 0,                 // positions fraîches
    timeout: 20000
  });

  const stop = function(){
    try { navigator.geolocation.clearWatch(watchId); } catch(e) {}
    // on garde le marqueur (plus lisible). Pour le retirer :
    // if (marker) { map.removeLayer(marker); marker = null; }
  };
  window.addEventListener('beforeunload', stop, { once: true });
  return stop;
}

// ======================== BOUTON SUIVI =========================
// Bouton Leaflet pour activer/désactiver l'autocentrage
// + coupe automatiquement le suivi dès que l'utilisateur manipule la carte.
function addFollowControl(map, startFn){
  const ctl = L.control({ position: 'topleft' });
  let following = true, stopFn = null, _btn = null;

  const refreshLabel = () => { if (_btn) _btn.textContent = following ? '📍 Suivre' : '📍 Libre'; };

  ctl.onAdd = function(){
    const btn = L.DomUtil.create('button');
    _btn = btn;
    btn.type = 'button';
    refreshLabel();
    btn.title = 'Activer/désactiver le suivi de ma position';
    btn.style.cssText = 'background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:6px 10px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.15);';
    L.DomEvent.on(btn, 'click', function(e){
      L.DomEvent.stopPropagation(e);
      following = !following;
      refreshLabel();
      if (stopFn) { stopFn(); stopFn = null; }
      if (following && typeof startFn === 'function') { stopFn = startFn({ follow:true }); }
    });
    return btn;
  };

  ctl.addTo(map);

  // démarre en mode "suivre"
  if (typeof startFn === 'function') { stopFn = startFn({ follow:true }); }

  // Dès que l'utilisateur manipule la carte, on coupe le follow
  const autoStopFollow = function(){
    if (!following) return;
    following = false;
    refreshLabel();
    if (stopFn) { stopFn(); stopFn = null; }
  };
  map.on('dragstart zoomstart', autoStopFollow);

  // renvoie un nettoyeur
  return function(){
    if (stopFn) stopFn();
    map.off('dragstart zoomstart', autoStopFollow);
  };
}

// ======================== BOOT AUTOMATIQUE =====================
// Démarre tout seul dès que la carte existe (Stimulus/Turbo friendly)
(function bootOnce(){
  let started = false;
  function findMap(){
    return (window.DeclicMap && window.DeclicMap.map) || window.map || window.__leafletMap || null;
  }
  function tryBoot(){
    if (started) return;
    const m = findMap();
    if (!m || !window.L) { setTimeout(tryBoot, 200); return; }
    started = true;
    addFollowControl(m, (opts)=> startGeoWatch(m, opts));
  }
  document.addEventListener('turbo:load', tryBoot);
  document.addEventListener('DOMContentLoaded', tryBoot);
  window.addEventListener('pageshow', tryBoot);
  tryBoot();
})();

