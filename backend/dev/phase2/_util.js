// Shared helpers for the dev/phase2 tools. They read env.js (Firebase + Mongo) because they upload to Storage.
export function argv(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

/** A point inside a zone polygon (its bounding-box centre; zones are rectangles). */
export function pickInsideZone(zone) {
  const ring = zone.polygon.coordinates[0];
  const lngs = ring.map((p) => p[0]);
  const lats = ring.map((p) => p[1]);
  return { lng: (Math.min(...lngs) + Math.max(...lngs)) / 2, lat: (Math.min(...lats) + Math.max(...lats)) / 2 };
}

export async function loadModels() {
  const [{ User }, { Zone }, { CheckIn }, { Hazard }, { SosEvent }, storage] = await Promise.all([
    import('../../src/models/User.js'),
    import('../../src/models/Zone.js'),
    import('../../src/models/CheckIn.js'),
    import('../../src/models/Hazard.js'),
    import('../../src/models/SosEvent.js'),
    import('../../src/core/storage.js'),
  ]);
  return { User, Zone, CheckIn, Hazard, SosEvent, uploadBuffer: storage.uploadBuffer };
}
