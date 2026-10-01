// Optional offline YOLO provider (onnxruntime-node). One-time laptop export, nothing in Python runs in production:
//   pip install ultralytics && yolo export model=best.pt format=onnx imgsz=640
//   then print the class names (model.names) and put them in ONNX_CLASSES (comma separated, in class-index order).
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { detectableKeysFor, summarizeDetections } from './yolo.map.js';

const SIZE = 640;
let sessionPromise;

/** Letterbox geometry for fitting (w x h) into size x size with centred padding. */
export function letterboxInfo(w, h, size = SIZE) {
  const scale = Math.min(size / w, size / h);
  const nw = Math.round(w * scale);
  const nh = Math.round(h * scale);
  return { scale, nw, nh, padX: Math.floor((size - nw) / 2), padY: Math.floor((size - nh) / 2) };
}

const iou = (a, b) => {
  const x1 = Math.max(a.x, b.x), y1 = Math.max(a.y, b.y), x2 = Math.min(a.x + a.w, b.x + b.w), y2 = Math.min(a.y + a.h, b.y + b.h);
  const inter = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  const uni = a.w * a.h + b.w * b.h - inter;
  return uni <= 0 ? 0 : inter / uni;
};

/**
 * Decodes a YOLOv8 output [1, 4+nc, N] (column-major per anchor): per column cx, cy, w, h then nc class scores.
 * Keeps the best class at >= confThreshold, undoes the letterbox, applies per-class NMS and returns the top 100.
 * Boxes are normalised 0..1 (top-left origin) against the ORIGINAL image.
 */
export function decodeYoloOutput(data, nc, { n, orig, lb, classes, confThreshold = 0.25, iouThreshold = 0.45, topK = 100 }) {
  const stride = n; // output is [4+nc][n]
  const cands = [];
  for (let i = 0; i < n; i++) {
    let best = -1, bestScore = 0;
    for (let c = 0; c < nc; c++) {
      const s = data[(4 + c) * stride + i];
      if (s > bestScore) (bestScore = s, best = c);
    }
    if (best < 0 || bestScore < confThreshold) continue;
    const cx = data[i], cy = data[stride + i], w = data[2 * stride + i], h = data[3 * stride + i];
    const x = (cx - w / 2 - lb.padX) / lb.scale;
    const y = (cy - h / 2 - lb.padY) / lb.scale;
    const bw = w / lb.scale, bh = h / lb.scale;
    cands.push({ cls: best, confidence: bestScore, box: { x: clamp(x / orig.width), y: clamp(y / orig.height), w: clamp(bw / orig.width), h: clamp(bh / orig.height) } });
  }
  cands.sort((a, b) => b.confidence - a.confidence);
  const kept = [];
  for (const c of cands) {
    if (kept.every((k) => k.cls !== c.cls || iou(k.box, c.box) < iouThreshold)) kept.push(c);
    if (kept.length >= topK) break;
  }
  return kept.map((k) => ({ label: classes[k.cls] ?? `class_${k.cls}`, confidence: k.confidence, box: k.box }));
}

const clamp = (v) => Math.max(0, Math.min(1, v));

async function getSession(modelPath) {
  if (!sessionPromise) {
    sessionPromise = (async () => {
      const resolved = path.resolve(process.cwd(), modelPath);
      if (!fs.existsSync(resolved)) throw new Error(`ONNX model not found at ${resolved}`);
      const ort = await import('onnxruntime-node');
      return { ort, session: await ort.InferenceSession.create(resolved) };
    })();
  }
  return sessionPromise;
}

export async function detectOnnx({ buffer, width, height }, cfg) {
  if (!cfg.onnxClasses.length) return { status: 'unavailable', reason: 'ONNX_CLASSES is not set' };
  const t0 = Date.now();
  let loaded;
  try {
    loaded = await getSession(cfg.onnxModelPath);
  } catch (e) {
    return { status: 'unavailable', reason: e.message };
  }
  const { ort, session } = loaded;
  const lb = letterboxInfo(width, height);
  const { data } = await sharp(buffer)
    .resize(lb.nw, lb.nh)
    .extend({ top: lb.padY, bottom: SIZE - lb.nh - lb.padY, left: lb.padX, right: SIZE - lb.nw - lb.padX, background: { r: 114, g: 114, b: 114 } })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const plane = SIZE * SIZE;
  const input = new Float32Array(3 * plane);
  for (let i = 0; i < plane; i++) {
    input[i] = data[i * 3] / 255;
    input[plane + i] = data[i * 3 + 1] / 255;
    input[2 * plane + i] = data[i * 3 + 2] / 255;
  }
  const feeds = { [session.inputNames[0]]: new ort.Tensor('float32', input, [1, 3, SIZE, SIZE]) };
  const out = await session.run(feeds);
  const t = out[session.outputNames[0]];
  const nc = t.dims[1] - 4;
  const raw = decodeYoloOutput(t.data, nc, { n: t.dims[2], orig: { width, height }, lb, classes: cfg.onnxClasses });
  return summarizeDetections(raw, { provider: 'onnx', detectableKeys: detectableKeysFor(cfg.onnxClasses), latencyMs: Date.now() - t0 });
}
