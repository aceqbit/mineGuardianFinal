import { withTimeout } from '../gemini.client.js';
import { ROBOFLOW_CLASSES, detectableKeysFor, summarizeDetections } from './yolo.map.js';

/**
 * Parses a Roboflow response. Predictions are { x, y, width, height, confidence, class } with x,y as the box CENTRE in pixels;
 * boxes are normalised to 0..1 with a top-left origin.
 */
export function parseRoboflow(json, fallbackSize = {}) {
  const w = json?.image?.width ?? fallbackSize.width ?? 1;
  const h = json?.image?.height ?? fallbackSize.height ?? 1;
  return (json?.predictions ?? []).map((p) => ({
    label: p.class,
    confidence: p.confidence,
    box: {
      x: clamp01((p.x - p.width / 2) / w),
      y: clamp01((p.y - p.height / 2) / h),
      w: clamp01(p.width / w),
      h: clamp01(p.height / h),
    },
  }));
}

const clamp01 = (v) => Math.max(0, Math.min(1, v));

async function post(base, path, key, base64) {
  const url = `${base}/${path}?api_key=${encodeURIComponent(key)}&confidence=25&overlap=45`;
  return fetch(url, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: base64 });
}

/** Roboflow hosted inference. On 404 / 401 / 5xx retries once on the detect.roboflow.com host with the same path. */
export async function detectRoboflow({ base64, width, height }, cfg) {
  if (!cfg.roboflowKey) return { status: 'unavailable', reason: 'ROBOFLOW_API_KEY is not set' };
  const t0 = Date.now();
  let res = await withTimeout(post('https://serverless.roboflow.com', cfg.roboflowModel, cfg.roboflowKey, base64), 7000, 'Roboflow');
  if ([404, 401].includes(res.status) || res.status >= 500) {
    res = await withTimeout(post('https://detect.roboflow.com', cfg.roboflowModel, cfg.roboflowKey, base64), 7000, 'Roboflow fallback');
  }
  if (!res.ok) return { status: 'error', reason: `Roboflow HTTP ${res.status}` };
  const json = await res.json();
  return summarizeDetections(parseRoboflow(json, { width, height }), { provider: 'roboflow', detectableKeys: detectableKeysFor(ROBOFLOW_CLASSES), latencyMs: Date.now() - t0 });
}
