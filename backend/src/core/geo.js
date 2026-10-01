const R = 6371008.8; // mean earth radius (m)
const rad = (d) => (d * Math.PI) / 180;

/** Great-circle distance in metres. Points are {lat,lng}. */
export function haversineM(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(s)));
}

/** Ray casting on the outer ring. polygon = GeoJSON Polygon {coordinates:[ring,...]} with [lng,lat]. */
export function pointInPolygon(point, polygon) {
  const ring = polygon?.coordinates?.[0];
  if (!ring || ring.length < 4) return false;
  const x = point.lng;
  const y = point.lat;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i];
    const [xj, yj] = ring[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

export const toPoint = (lat, lng) => ({ type: 'Point', coordinates: [lng, lat] });
export const fromPoint = (p) => (p?.coordinates ? { lat: p.coordinates[1], lng: p.coordinates[0] } : null);

/** Offset in metres (x east, y north) -> degrees at a given latitude. */
export function metersToLatLng(xM, yM, atLat) {
  return { dLat: yM / 111320, dLng: xM / (111320 * Math.cos(rad(atLat))) };
}

/** Local metre grid (x east, y north) around an anchor -> {lat,lng}. */
export function localToLatLng(anchor, xM, yM) {
  const { dLat, dLng } = metersToLatLng(xM, yM, anchor.lat);
  return { lat: anchor.lat + dLat, lng: anchor.lng + dLng };
}

/** Inverse: {lat,lng} -> local metres around anchor. */
export function latLngToLocal(anchor, p) {
  return {
    x: (p.lng - anchor.lng) * 111320 * Math.cos(rad(anchor.lat)),
    y: (p.lat - anchor.lat) * 111320,
  };
}
