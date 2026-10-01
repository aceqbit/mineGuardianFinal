// Usage: node src/modules/ai-analyzer/cli.js --mode ppe|hazard --image <path> [--zone Z-B] [--category ELECTRICAL]
// Works without MongoDB. ML_MODE=mock needs no API key.
import fs from 'node:fs';
import { analyzeImage } from './analyzer.js';
import { DEFAULT_REQUIRED_PPE } from './config.js';

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const ZONE_PPE = {
  'Z-A': ['HELMET', 'CAP_LAMP', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES', 'SELF_RESCUER'],
  'Z-B': ['HELMET', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES'],
  'Z-C': ['HELMET', 'CAP_LAMP', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES', 'SELF_RESCUER', 'DUST_MASK', 'EAR_PROTECTION', 'EYE_PROTECTION'],
};

const mode = arg('mode', 'ppe');
const imagePath = arg('image');
if (!imagePath || !fs.existsSync(imagePath)) {
  console.error('Usage: node src/modules/ai-analyzer/cli.js --mode ppe|hazard --image <path> [--zone Z-B] [--category ELECTRICAL]');
  process.exit(1);
}
const zone = arg('zone', 'Z-B');
const context = {
  zoneCode: zone, shift: 'B', capturedAt: new Date().toISOString(), source: 'camera',
  requiredPpe: ZONE_PPE[zone] ?? [...DEFAULT_REQUIRED_PPE], category: arg('category', 'OTHER'), integrityFlags: [],
};

const result = await analyzeImage({ mode, imageBuffer: fs.readFileSync(imagePath), context });
console.log(JSON.stringify(result, null, 2));

console.log('\n--- summary ---');
if (result.mode === 'PPE_COMPLIANCE') {
  console.table(result.items.filter((i) => i.required).map((i) => ({ item: i.key, status: i.status, confidence: i.confidence, source: i.source })));
  console.log(`verdict: ${result.overallVerdict} (${result.overallConfidence})  criticality: ${result.criticality.level} ${result.criticality.score}/100`);
} else {
  console.log(`severity: ${result.severity} (${result.severityConfidence})  criticality: ${result.criticality.level} ${result.criticality.score}/100`);
}
console.log(`emergency: detected=${result.emergency.detected} possible=${result.emergency.possible}  model: ${result.model}  latency: ${result.latencyMs} ms`);
if (result.error) console.log(`error: ${result.error.code} — ${result.error.message}`);
