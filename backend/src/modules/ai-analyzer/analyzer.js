import { AiBlockedError, prepare } from './image.prep.js';
import { aiConfig, DEFAULT_REQUIRED_PPE } from './config.js';
import { generateJson, inlineImagePart } from './gemini.client.js';
import { hazardResponseSchema, hazardZod, ppeResponseSchema, ppeZod } from './schemas.js';
import { SYSTEM_CORE, STAGE_B_SUFFIX, taskHazard, taskPpe } from './prompts.js';
import {
  applyRelevance, composeSummary, computeCriticality, computeOverallConfidence, computeVerdict, emergencyGate, hazardGuard, normalizeItems,
} from './guardrails.js';
import { mockHazardRaw, mockPpeRaw } from './mock.js';

const MODE_PPE = 'PPE_COMPLIANCE';

const camelReport = (r) => ({ observations: r?.observations ?? [], risks: r?.risks ?? [], recommendedActions: r?.recommended_actions ?? [] });

/**
 * Turns the model's raw (snake_case, zod-valid) PPE answer into the contract's `ai` object. Deterministic.
 * `yolo` and `fuse` are supplied by the agent (P2.2); without them the result is Gemini-only.
 */
export function finalizePpe(raw, { required, context = {}, model, latencyMs, yolo = null, fuse = null, toolTrace = [], imageQuality = null }) {
  let items = normalizeItems(raw.items, required);
  const conflicts = [...(raw.conflicts ?? [])];
  const limitations = [...(raw.limitations ?? [])];
  if (fuse) {
    const f = fuse(items, { yolo, imageQuality });
    items = f.items;
    conflicts.push(...f.conflicts);
    limitations.push(...f.limitations);
  } else {
    items = items.map((i) => (i.required ? { ...i, confidence: Math.min(i.confidence, 0.85) } : i));
  }
  items = normalizeItems(items, required).map((i, idx) => ({ ...i, source: items[idx]?.source ?? i.source })); // re-apply the 0.60 rule after fusion
  items = applyRelevance(items, raw.image_relevance);
  if (raw.image_relevance === 'IRRELEVANT' && !limitations.includes('Image is not a genuine photograph')) limitations.push('Image is not a genuine photograph');

  const emergency = emergencyGate(raw.emergency, { yoloFall: yolo?.fallDetected });
  const verdict = computeVerdict(items, { fullBodyVisible: raw.framing.full_body_visible, imageQuality: imageQuality?.verdict ?? 'ok' });
  const overallConfidence = computeOverallConfidence(items, verdict);
  const criticality = computeCriticality(items, { repeatOffender: !!context.repeatOffender, integrityFlags: context.integrityFlags ?? [], emergencyDetected: emergency.detected, ageAtUploadMin: context.ageAtUploadMin ?? null });

  return {
    mode: MODE_PPE,
    model,
    yoloProvider: yolo?.provider ?? 'none',
    imageRelevance: raw.image_relevance,
    framing: { fullBodyVisible: raw.framing.full_body_visible, personsCount: raw.framing.persons_count, notes: raw.framing.notes },
    items,
    overallVerdict: verdict,
    overallConfidence,
    criticality,
    emergency,
    conflicts,
    limitations,
    summary: composeSummary(verdict, criticality, raw.summary),
    report: camelReport(raw.report),
    yoloDetections: yolo?.detections ?? [],
    imageQuality: imageQuality ?? {},
    toolTrace,
    latencyMs,
  };
}

export function finalizeHazard(raw, { model, latencyMs, toolTrace = [], limitations: extraLimitations = [] }) {
  const emergency = emergencyGate(raw.emergency, {});
  const g = hazardGuard(raw, emergency);
  return {
    mode: 'HAZARD_SCENE',
    model,
    imageRelevance: raw.image_relevance,
    hazardDescription: raw.hazard_description,
    categoryClaimed: raw.category_claimed,
    categoryObserved: raw.category_observed,
    categoryMatches: raw.category_matches,
    severity: g.severity,
    severityConfidence: g.severityConfidence,
    affectedAreaEstimate: raw.affected_area_estimate,
    criticality: g.criticality,
    emergency,
    limitations: [...g.limitations, ...extraLimitations],
    summary: composeSummary(g.severity === 'CRITICAL' ? 'NON_COMPLIANT' : 'COMPLIANT', g.criticality, raw.summary).replace(/^(Non-compliant|Compliant) · /, `${g.severity} · `),
    report: camelReport(raw.report),
    toolTrace,
    latencyMs,
  };
}

function failurePpe(required, err, latencyMs, model = 'none') {
  const items = normalizeItems([], required);
  const criticality = computeCriticality(items, {});
  return {
    mode: MODE_PPE, model, yoloProvider: 'none', imageRelevance: 'RELEVANT', framing: { fullBodyVisible: false, personsCount: 0, notes: '' }, items,
    overallVerdict: 'NEEDS_MANUAL_REVIEW', overallConfidence: 0, criticality, emergency: { detected: false, possible: false, type: 'NONE', confidence: 0, evidence: '' },
    conflicts: [], limitations: ['AI analysis failed; manual review required'], summary: 'AI could not assess this photo — manual review required',
    report: { observations: [], risks: [], recommendedActions: ['Review the photo manually'] }, yoloDetections: [], imageQuality: {}, toolTrace: [], latencyMs,
    error: { code: err?.code ?? 'AI_ERROR', message: String(err?.message ?? err).slice(0, 300) },
  };
}

function failureHazard(err, latencyMs, claimed) {
  return {
    mode: 'HAZARD_SCENE', model: 'none', imageRelevance: 'RELEVANT', hazardDescription: '', categoryClaimed: claimed, categoryObserved: claimed, categoryMatches: false,
    severity: null, severityConfidence: 0, affectedAreaEstimate: '', criticality: { level: 'NONE', score: 0, drivers: [] },
    emergency: { detected: false, possible: false, type: 'NONE', confidence: 0, evidence: '' }, limitations: ['AI analysis failed; manual review required'],
    summary: 'AI could not assess this photo — manual review required', report: { observations: [], risks: [], recommendedActions: [] }, toolTrace: [], latencyMs,
    error: { code: err?.code ?? 'AI_ERROR', message: String(err?.message ?? err).slice(0, 300) },
  };
}

/** Image bytes -> contract `ai` object. NEVER throws: failures degrade to NEEDS_MANUAL_REVIEW (PPE) or severity null (hazard). */
export async function analyzeImage({ mode, imageBuffer, context = {} }, cfg = aiConfig()) {
  const t0 = Date.now();
  const isHazard = mode === 'hazard' || mode === 'HAZARD_SCENE';
  const required = context.requiredPpe?.length ? context.requiredPpe : [...DEFAULT_REQUIRED_PPE];
  try {
    const img = await prepare(imageBuffer);
    if (cfg.mlMode === 'mock') {
      const raw = isHazard ? mockHazardRaw(img.sha256, context) : mockPpeRaw(img.sha256, required);
      return isHazard ? finalizeHazard(raw, { model: 'mock', latencyMs: Date.now() - t0 }) : finalizePpe(raw, { required, context, model: 'mock', latencyMs: Date.now() - t0 });
    }
    // Stage B only in P2.1: one call with the image, the task text and the Stage B suffix with an empty dossier.
    const task = isHazard ? taskHazard(context) : taskPpe({ ...context, requiredPpe: required });
    const parts = [inlineImagePart(img.base64), { text: `${task}\n\nEVIDENCE DOSSIER: {}\n\n${STAGE_B_SUFFIX}` }];
    const { data, model, latencyMs } = await generateJson(
      { systemInstruction: SYSTEM_CORE, parts, schema: isHazard ? hazardResponseSchema : ppeResponseSchema, zodSchema: isHazard ? hazardZod : ppeZod },
      cfg,
    );
    return isHazard ? finalizeHazard(data, { model, latencyMs }) : finalizePpe(data, { required, context, model, latencyMs });
  } catch (err) {
    const latency = Date.now() - t0;
    return isHazard ? failureHazard(err, latency, context.category ?? 'OTHER') : failurePpe(required, err, latency);
  }
}

export { AiBlockedError };
