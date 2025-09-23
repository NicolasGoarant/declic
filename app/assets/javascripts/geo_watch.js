/* global L */
// Démarre un suivi GPS continu. Retourne une fonction stop().
// opts: { follow: boolean, accuracy: boolean, maxAgeMs: number, highAccuracy: boolean }
function startGeoWatch(map, opts){
  if (!('geolocation' in navigator) || !map) {
    console.warn('Geolocation non dispo ou map manquante');
    return function(){};
  }
  const cfg = Object.assign({
    follow: true,
    accuracy: true,
    maxAgeMs: 10000,
    highAccuracy: true
  }, opts || {});

  let marker = null, circle = null, lastPan = 0;

  const onPos = (pos) => {
    const c = (pos && pos.coords) || {};
    const lat = typeof c.latitude === 'number' ? c.latitude : null;
    const lng = typeof c.longitude === 'number' ? c.longitude : null;
    const acc = typeof c.accuracy === 'number' ? c.accuracy : null;
    if (lat === null || lng === null) return;

    if (!marker) {
      marker = L.marker([lat, lng], {
        icon: L.divIcon({
          className: '',
          html: '<div style="width:18px;height:18px;border-radius:9999px;background:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.35);border:2px solid #fff;"></div>',
          iconSize: [18,18],
          iconAnchor: [9,9]
        })
      }).addTo(map);
    } else {
      marker.setLatLng([lat, lng]);
    }

    if (cfg.accuracy) {
      const r = Math.max(10, Math.min(acc || 0, 400));
      if (!circle) {
        circle = L.circle([lat, lng], { radius: r, color: '#2563eb', weight: 1, fillColor: '#60a5fa', fillOpacity: 0.2 }).addTo(map);
      } else {
        circle.setLatLng([lat, lng]).setRadius(r);
      }
    }

    if (cfg.follow) {
      const now = Date.now();
      if (now - lastPan > 800) {
        map.panTo([lat, lng], { animate: true, duration: 0.6 });
        lastPan = now;
      }
    }
  };

  const onErr = (err) => console.warn('Geolocation error:', (err && err.message) || err);

  const watchId = navigator.geolocation.watchPosition(onPos, onErr, {
    enableHighAccuracy: !!cfg.highAccuracy,
    maximumAge: cfg.maxAgeMs,
    timeout: 10000
  });

  const stop = function(){
    try { navigator.geolocation.clearWatch(watchId); } catch(e) {}
  };
  window.addEventListener('beforeunload', stop, { once: true });
  return stop;
}

// Bouton Leaflet pour activer/désactiver l'autocentrage
// + coupe automatiquement le suivi dès que l'utilisateur manipule la carte.
function addFollowControl(map, startFn){
  const ctl = L.control({ position: 'topleft' });
  let following = true, stopFn = null, _btn = null;

  ctl.onAdd = function(){
    const btn = L.DomUtil.create('button');
    _btn = btn;
    btn.type = 'button';
    btn.textContent = '📍 Suivre';
    btn.title = 'Activer/désactiver le suivi de ma position';
    btn.style.cssText = 'background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:6px 10px;cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.15);';
    L.DomEvent.on(btn, 'click', function(e){
      L.DomEvent.stopPropagation(e);
      following = !following;
      btn.textContent = following ? '📍 Suivre' : '📍 Libre';
      if (stopFn) { stopFn(); stopFn = null; }
      if (following && typeof startFn === 'function') { stopFn = startFn({ follow:true }); }
    });
    return btn;
  };

  ctl.addTo(map);

  // démarre en mode "suivre"
  if (typeof startFn === 'function') { stopFn = startFn({ follow:true }); }

  // 🔻 Dès que l'utilisateur manipule la carte, on coupe le follow
  const autoStopFollow = function(){
    if (!following) return;            // déjà libre
    following = false;
    if (_btn) _btn.textContent = '📍 Libre';
    if (stopFn) { stopFn(); stopFn = null; }
  };
  map.on('dragstart zoomstart', autoStopFollow);

  // renvoie un nettoyeur
  return function(){
    if (stopFn) stopFn();
    map.off('dragstart zoomstart', autoStopFollow);
  };
}
