/* global L */
function addFallbackTiles(map){
  const providers = [
    { url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      options: { maxZoom: 19, attribution: '© OpenStreetMap' } },
    { url: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
      options: { subdomains: 'abc', maxZoom: 19, attribution: '© OpenStreetMap, © OSM-FR' } },
    { url: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
      options: { subdomains: 'abcd', maxZoom: 19, attribution: '© OpenStreetMap, © Carto' } }
  ];
  let layer = null, idx = 0;
  const tryNext = () => {
    if (layer) { map.removeLayer(layer); layer = null; }
    if (idx >= providers.length) { console.warn('Aucune source de tuiles n’a répondu'); return null; }
    const p = providers[idx++]; layer = L.tileLayer(p.url, p.options);
    let loaded = false;
    const onLoad = () => { loaded = true; layer.off('load', onLoad); layer.off('tileerror', onErr); };
    const onErr  = () => setTimeout(() => { if (!loaded) tryNext(); }, 600);
    layer.on('load', onLoad); layer.on('tileerror', onErr);
    layer.addTo(map); return layer;
  };
  return tryNext();
}
