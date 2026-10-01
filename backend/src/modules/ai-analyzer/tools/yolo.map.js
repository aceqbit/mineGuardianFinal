// Maps detector class names to PPE keys + polarity. '+' means worn, '-' means a "NO-..." class. Case, space and hyphen insensitive.
const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '');

const TABLE = {
  // Roboflow "personal-protective-equipment-combined-model"
  hardhat: ['HELMET', '+'], nohardhat: ['HELMET', '-'],
  safetyvest: ['REFLECTIVE_VEST', '+'], nosafetyvest: ['REFLECTIVE_VEST', '-'],
  gloves: ['GLOVES', '+'], nogloves: ['GLOVES', '-'],
  goggles: ['EYE_PROTECTION', '+'], nogoggles: ['EYE_PROTECTION', '-'],
  mask: ['DUST_MASK', '+'], nomask: ['DUST_MASK', '-'],
  // Hugging Face yolov8n-ppe-6class (ONNX)
  helmet: ['HELMET', '+'], nohelmet: ['HELMET', '-'],
  vest: ['REFLECTIVE_VEST', '+'], novest: ['REFLECTIVE_VEST', '-'],
  safetyshoe: ['SAFETY_BOOTS', '+'], safetyshoes: ['SAFETY_BOOTS', '+'], boots: ['SAFETY_BOOTS', '+'], noboots: ['SAFETY_BOOTS', '-'],
  glove: ['GLOVES', '+'], goggle: ['EYE_PROTECTION', '+'],
};

const PERSON = new Set(['person', 'worker', 'human']);
const FALL = new Set(['falldetected', 'fall', 'falling']);
const IGNORE = new Set(['ladder', 'safetycone', 'cone', 'machinery', 'vehicle', 'truck']);

/** -> { kind: 'ppe'|'person'|'fall'|'ignore'|'unknown', ppeKey, polarity } */
export function mapLabel(label) {
  const n = norm(label);
  if (TABLE[n]) return { kind: 'ppe', ppeKey: TABLE[n][0], polarity: TABLE[n][1] };
  if (PERSON.has(n)) return { kind: 'person', ppeKey: null, polarity: null };
  if (FALL.has(n)) return { kind: 'fall', ppeKey: null, polarity: null };
  if (IGNORE.has(n)) return { kind: 'ignore', ppeKey: null, polarity: null };
  return { kind: 'unknown', ppeKey: null, polarity: null };
}

/** PPE keys a model can detect given its class names. */
export function detectableKeysFor(classNames) {
  const keys = new Set();
  for (const c of classNames) {
    const m = mapLabel(c);
    if (m.kind === 'ppe') keys.add(m.ppeKey);
  }
  return [...keys];
}

export const ROBOFLOW_CLASSES = ['Hardhat', 'NO-Hardhat', 'Safety Vest', 'NO-Safety Vest', 'Gloves', 'NO-Gloves', 'Goggles', 'NO-Goggles', 'Mask', 'NO-Mask', 'Person', 'Fall-Detected', 'Ladder', 'Safety Cone'];

/** Turns raw detections [{label, confidence, box}] into the tool result shape. Unknown labels are kept with ppeKey null. */
export function summarizeDetections(raw, { provider, detectableKeys, latencyMs }) {
  const detections = raw.map((d) => {
    const m = mapLabel(d.label);
    return { label: d.label, ppeKey: m.ppeKey, polarity: m.polarity, kind: m.kind, confidence: round(d.confidence), box: d.box };
  }).filter((d) => d.kind !== 'ignore');
  const persons = detections.filter((d) => d.kind === 'person');
  const main = persons.length ? persons.reduce((a, b) => (a.box.w * a.box.h >= b.box.w * b.box.h ? a : b)) : null;
  const falls = detections.filter((d) => d.kind === 'fall');
  const fall = falls.length ? Math.max(...falls.map((f) => f.confidence)) : 0;
  return {
    status: 'ok',
    provider,
    detections: detections.filter((d) => d.kind !== 'person' && d.kind !== 'fall').map(({ kind, ...rest }) => rest),
    personCount: persons.length,
    mainPersonBox: main ? main.box : null,
    fallDetected: { value: fall > 0, confidence: fall },
    detectableKeys,
    latencyMs,
  };
}

const round = (n) => Math.round(n * 1000) / 1000;
