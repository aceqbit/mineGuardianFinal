// Usage: node src/modules/ai-analyzer/eval/run.js [--mode hybrid|gemini_only|yolo_only|mock] [--set adversarial]
// Reads eval/labels.json (or adversarial.json), analyses every image (concurrency 2), prints the metrics and saves eval/report-<timestamp>.json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyzeImage } from '../analyzer.js';
import { aiConfig, ZONE_REQUIRED_PPE } from '../config.js';
import { computeMetrics, meetsTargets, TARGETS } from './metrics.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const arg = (n, d) => {
  const i = process.argv.indexOf(`--${n}`);
  return i >= 0 ? process.argv[i + 1] : d;
};

const set = arg('set', 'labels');
const labelsPath = path.join(here, `${set === 'adversarial' ? 'adversarial' : 'labels'}.json`);
if (!fs.existsSync(labelsPath)) {
  console.error(`Missing ${labelsPath}. See docs/ (P2.0): add your photos in eval/images/ and write the labels file by hand.`);
  process.exit(1);
}
const labels = JSON.parse(fs.readFileSync(labelsPath, 'utf8'));
const env = { ...process.env };
if (arg('mode')) env.ML_MODE = arg('mode');
const cfg = aiConfig(env);

const results = new Array(labels.length);
let next = 0;
async function worker() {
  while (next < labels.length) {
    const i = next++;
    const l = labels[i];
    const file = path.join(here, 'images', l.file);
    if (!fs.existsSync(file)) {
      console.warn(`skip ${l.file}: file not found`);
      results[i] = { mode: l.mode, overallVerdict: 'NEEDS_MANUAL_REVIEW', items: [], emergency: {}, latencyMs: null, error: { code: 'MISSING_FILE' } };
      continue;
    }
    const context = { zoneCode: l.zone ?? 'Z-B', requiredPpe: ZONE_REQUIRED_PPE[l.zone ?? 'Z-B'], category: l.category, shift: 'B', capturedAt: new Date().toISOString(), source: 'camera', integrityFlags: [] };
    results[i] = await analyzeImage({ mode: l.mode === 'HAZARD_SCENE' ? 'hazard' : 'ppe', imageBuffer: fs.readFileSync(file), context }, cfg);
    process.stdout.write(`${i + 1}/${labels.length} ${l.file} -> ${results[i].overallVerdict ?? results[i].severity}\n`);
  }
}
await Promise.all([worker(), worker()]);

const metrics = computeMetrics(labels, results);
const ok = meetsTargets(metrics);
console.log('\n=== Evaluation ===');
console.table({
  'verdict accuracy %': { value: metrics.verdictAccuracy, target: `>= ${TARGETS.verdictAccuracy}`, ok: ok.verdictAccuracy },
  'ABSENT recall %': { value: metrics.absentRecall, target: `>= ${TARGETS.absentRecall}`, ok: ok.absentRecall },
  'false emergencies': { value: metrics.falseEmergencies, target: `= ${TARGETS.falseEmergencies}`, ok: ok.falseEmergencies },
  'p95 latency ms': { value: metrics.latencyP95Ms, target: `<= ${TARGETS.latencyP95Ms}`, ok: ok.latencyP95Ms },
});
console.log('ABSENT precision %:', metrics.absentPrecision, ' UNCERTAIN rate %:', metrics.uncertainRate, ' hazard severity accuracy %:', metrics.hazardSeverityAccuracy, ' mean latency ms:', metrics.latencyMeanMs);
console.log('confusion:', metrics.confusion);
if (metrics.adversarial.checked) console.log('adversarial:', metrics.adversarial.unsafe.length ? `UNSAFE -> ${metrics.adversarial.unsafe.join(', ')}` : `${metrics.adversarial.checked}/${metrics.adversarial.checked} safe`, metrics.adversarial.irrelevantMiss.length ? `| not flagged IRRELEVANT: ${metrics.adversarial.irrelevantMiss.join(', ')}` : '');
if (metrics.misclassified.length) {
  console.log('\nMisclassified (tune only config numbers and the "known confusions" prompt lines):');
  for (const m of metrics.misclassified) console.log(`- ${m.file}: expected ${m.expected}, got ${m.got}\n    ${(m.evidence ?? []).join('\n    ')}`);
}
const out = path.join(here, `report-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
fs.writeFileSync(out, JSON.stringify({ at: new Date().toISOString(), mode: cfg.mlMode, set, metrics, results }, null, 2));
console.log(`\nReport saved: ${out}`);
const failed = Object.values(ok).some((v) => !v) || metrics.adversarial.unsafe.length > 0;
process.exit(failed ? 1 : 0);
