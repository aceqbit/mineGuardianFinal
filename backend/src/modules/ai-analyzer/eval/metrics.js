// Pure evaluation metrics. labels[i] and results[i] correspond.
const pct = (n, d) => (d === 0 ? null : Math.round((1000 * n) / d) / 10);

export function percentile(values, p) {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.max(0, Math.ceil((p / 100) * s.length) - 1))];
}

/**
 * label: { file, mode, expected: { verdict?, items?{KEY:status}, notVerdicts?[], relevance?, severity?, emergency? } }
 * result: the analyser's `ai` object.
 */
export function computeMetrics(labels, results) {
  const ppe = labels.map((l, i) => ({ l, r: results[i] })).filter((x) => x.l.mode === 'PPE_COMPLIANCE');
  const hz = labels.map((l, i) => ({ l, r: results[i] })).filter((x) => x.l.mode === 'HAZARD_SCENE');

  // verdict accuracy + confusion
  const withVerdict = ppe.filter((x) => x.l.expected?.verdict);
  const confusion = {};
  let verdictOk = 0;
  const misses = [];
  for (const { l, r } of withVerdict) {
    const key = `${l.expected.verdict} -> ${r.overallVerdict}`;
    confusion[key] = (confusion[key] ?? 0) + 1;
    if (r.overallVerdict === l.expected.verdict) verdictOk++;
    else misses.push({ file: l.file, expected: l.expected.verdict, got: r.overallVerdict, evidence: r.items?.filter((i) => i.required).map((i) => `${i.key}:${i.status}(${i.confidence}) ${i.evidence}`) });
  }

  // adversarial safety: never COMPLIANT where forbidden, irrelevant where expected
  const forbidden = ppe.filter((x) => x.l.expected?.notVerdicts);
  const unsafe = forbidden.filter((x) => x.l.expected.notVerdicts.includes(x.r.overallVerdict)).map((x) => x.l.file);
  const irrelevantMiss = ppe.filter((x) => x.l.expected?.relevance && x.r.imageRelevance !== x.l.expected.relevance).map((x) => x.l.file);

  // per-key ABSENT precision / recall
  const keys = new Map();
  for (const { l, r } of ppe) {
    for (const [key, expectedStatus] of Object.entries(l.expected?.items ?? {})) {
      const got = r.items?.find((i) => i.key === key)?.status;
      const k = keys.get(key) ?? { tp: 0, fp: 0, fn: 0 };
      if (expectedStatus === 'ABSENT' && got === 'ABSENT') k.tp++;
      else if (expectedStatus !== 'ABSENT' && got === 'ABSENT') k.fp++;
      else if (expectedStatus === 'ABSENT' && got !== 'ABSENT') k.fn++;
      keys.set(key, k);
    }
  }
  const absent = {};
  let tp = 0, fp = 0, fn = 0;
  for (const [key, k] of keys) {
    absent[key] = { precision: pct(k.tp, k.tp + k.fp), recall: pct(k.tp, k.tp + k.fn), ...k };
    tp += k.tp; fp += k.fp; fn += k.fn;
  }

  // UNCERTAIN rate over required items
  let uncertain = 0, requiredTotal = 0;
  for (const { r } of ppe) for (const i of r.items ?? []) if (i.required) { requiredTotal++; if (i.status === 'UNCERTAIN') uncertain++; }

  // false emergencies
  const all = labels.map((l, i) => ({ l, r: results[i] }));
  const falseEmergencies = all.filter(({ l, r }) => r.emergency?.detected === true && !l.expected?.emergency).map(({ l }) => l.file);

  const hazardOk = hz.filter((x) => x.l.expected?.severity && x.r.severity === x.l.expected.severity).length;
  const hazardTotal = hz.filter((x) => x.l.expected?.severity).length;

  const lat = results.map((r) => r.latencyMs).filter((v) => typeof v === 'number');
  return {
    total: labels.length,
    verdictAccuracy: pct(verdictOk, withVerdict.length),
    absentRecall: pct(tp, tp + fn),
    absentPrecision: pct(tp, tp + fp),
    absentByKey: absent,
    uncertainRate: pct(uncertain, requiredTotal),
    falseEmergencies: falseEmergencies.length,
    falseEmergencyFiles: falseEmergencies,
    hazardSeverityAccuracy: pct(hazardOk, hazardTotal),
    latencyMeanMs: lat.length ? Math.round(lat.reduce((a, b) => a + b, 0) / lat.length) : null,
    latencyP95Ms: percentile(lat, 95),
    confusion,
    misclassified: misses,
    adversarial: { checked: forbidden.length, unsafe, irrelevantMiss },
  };
}

export const TARGETS = { verdictAccuracy: 85, absentRecall: 90, falseEmergencies: 0, latencyP95Ms: 15000 };

export function meetsTargets(m) {
  return {
    verdictAccuracy: m.verdictAccuracy == null || m.verdictAccuracy >= TARGETS.verdictAccuracy,
    absentRecall: m.absentRecall == null || m.absentRecall >= TARGETS.absentRecall,
    falseEmergencies: m.falseEmergencies <= TARGETS.falseEmergencies,
    latencyP95Ms: m.latencyP95Ms == null || m.latencyP95Ms <= TARGETS.latencyP95Ms,
  };
}
