import { prepare } from './image.prep.js';
import { aiConfig, DEFAULT_REQUIRED_PPE } from './config.js';
import { generateJson, inlineImagePart } from './gemini.client.js';
import { hazardResponseSchema, hazardZod, ppeResponseSchema, ppeZod } from './schemas.js';
import { SYSTEM_CORE, STAGE_B_SUFFIX, taskHazard, taskPpe } from './prompts.js';
import {
  applyRelevance, composeSummary, computeCriticality, computeOverallConfidence, computeVerdict, emergencyGate, hazardGuard, normalizeItems,
} from './guardrails.js';
import { fuse, yoloOnlyRaw } from './fusion.js';
import { investigate } from './agent.js';
import { mockHazardRaw, mockPpeRaw } from './mock.js';

const MODE_PPE = 'PPE_COMPLIANCE';

const camelReport = (r) => ({ observations: r?.observations ?? [], risks: r?.risks ?? [], recommendedActions: r?.recommended_actions ?? [] });

/**
 * Turns the model's raw (snake_case, zod-valid) PPE answer into the contract's `ai` object. Deterministic.
 * Order: fusion -> normalizeItems (the 0.60 rule applies after fusion) -> relevance -> emergencyGate -> verdict -> confidence -> criticality -> summary.
 */
export function finalizePpe(raw, { required, context = {}, model, latencyMs, yolo = null, doFuse = true, toolTrace = [], imageQuality = null, extraLimitations = [] }) {
  let items = normalizeItems(raw.items, required);
  const conflicts = [...(raw.conflicts ?? [])];
  const limitations = [...(raw.limitations ?? []), ...extraLimitations];
  if (doFuse) {
    const f = fuse(items, { yolo, imageQuality });
    items = f.items;
    conflicts.push(...f.conflicts);
    for (const l of f.limitations) if (!limitations.includes(l)) limitations.push(l);
  }
  const sources = new Map(items.map((i) => [i.key, i.source]));
  items = normalizeItems(items, required).map((i) => ({ ...i, source: sources.get(i.key) ?? i.source }));
  items = applyRelevance(items, raw.image_relevance);
  if (raw.image_relevance === 'IRRELEVANT' && !limitations.includes('Image is not a genuine photograph')) limitations.push('Image is not a genuine photograph');

  const emergency = emergencyGate(raw.emergency, { yoloFall: yolo?.fallDetected });
  const verdict = computeVerdict(items, { fullBodyVisible: raw.framing.full_body_visible, imageQuality: imageQuality?.verdict ?? 'ok' });
  const overallConfidence = computeOverallConfidence(items, verdict);
  const criticality = computeCriticality(items, { repeatOffender: !!context.repeatOffender, integrityFlags: context.integrityFlags ?? [], emergencyDetected: emergency.detected, ageAtUploadMin: context.ageAtUploadMin ?? null });

  return {
    mode: MODE_PPE,
    model,
    yoloProvider: yolo?.status === 'ok' ? yolo.provider : 'none',
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
    yoloDetections: yolo?.status === 'ok' ? yolo.detections : [],
    imageQuality: imageQuality ?? {},
    toolTrace,
    latencyMs,
  };
}

export function finalizeHazard(raw, { model, latencyMs, toolTrace = [], extraLimitations = [] }) {
  const emergency = emergencyGate(raw.emergency, {});
  const g = hazardGuard(raw, emergency);
  const head = `${g.severity} · ${g.criticality.level} ${g.criticality.score}/100`;
  const summary = `${head}${raw.summary ? ` — ${raw.summary.trim()}` : ''}`.slice(0, 300);
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
    summary,
    report: camelReport(raw.report),
    toolTrace,
    latencyMs,
  };
}

function failurePpe(required, err, latencyMs) {
  const items = normalizeItems([], required);
  const criticality = computeCriticality(items, {});
  return {
    mode: MODE_PPE, model: 'none', yoloProvider: 'none', imageRelevance: 'RELEVANT', framing: { fullBodyVisible: false, personsCount: 0, notes: '' }, items,
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

/**
 * Image bytes -> the contract's `ai` object. NEVER throws: failures degrade to NEEDS_MANUAL_REVIEW (PPE) or severity null (hazard).
 * context: { zoneCode, requiredPpe, shift, capturedAt, source, integrityFlags, repeatOffender, checkInId, workerId, category }
 */
export async function analyzeImage({ mode, imageBuffer, context = {} }, cfg = aiConfig()) {
  const t0 = Date.now();
  const isHazard = mode === 'hazard' || mode === 'HAZARD_SCENE';
  const required = context.requiredPpe?.length ? context.requiredPpe : [...DEFAULT_REQUIRED_PPE];
  try {
    const img = await prepare(imageBuffer);

    if (cfg.mlMode === 'mock') {
      const raw = isHazard ? mockHazardRaw(img.sha256, context) : mockPpeRaw(img.sha256, required);
      return isHazard
        ? finalizeHazard(raw, { model: 'mock', latencyMs: Date.now() - t0 })
        : finalizePpe(raw, { required, context, model: 'mock', latencyMs: Date.now() - t0, doFuse: false });
    }

    const inv = await investigate({ img, isHazard, context, cfg, required });
    if (inv.integrity?.status === 'ok' && inv.integrity.ageAtUploadMin != null) context = { ...context, ageAtUploadMin: inv.integrity.ageAtUploadMin };
    const extra = [];
    if (inv.stageAError) extra.push(`Tool investigation incomplete: ${inv.stageAError}`);
    for (const u of inv.unavailable) extra.push(`Tool unavailable: ${u}`);

    // yolo_only: no Gemini at all
    if (cfg.mlMode === 'yolo_only' || !cfg.apiKey) {
      if (isHazard || cfg.mlMode !== 'yolo_only') throw Object.assign(new Error('GEMINI_API_KEY is not set'), { code: 'NO_API_KEY' });
      return finalizePpe(yoloOnlyRaw(required, inv.yolo), { required, context, model: 'yolo-only', latencyMs: Date.now() - t0, yolo: inv.yolo, doFuse: false, toolTrace: inv.trace, imageQuality: inv.quality, extraLimitations: extra });
    }

    const task = isHazard ? taskHazard(context) : taskPpe({ ...context, requiredPpe: required });
    const dossierText = JSON.stringify(inv.dossier);
    const parts = [
      inlineImagePart(img.base64),
      { text: `${task}\n\nEVIDENCE DOSSIER:\n${dossierText}\n\nSTAGE A NOTES:\n${inv.stageANotes || '(none)'}\n\n${STAGE_B_SUFFIX}` },
    ];
    const { data, model } = await generateJson(
      { systemInstruction: SYSTEM_CORE, parts, schema: isHazard ? hazardResponseSchema : ppeResponseSchema, zodSchema: isHazard ? hazardZod : ppeZod },
      cfg,
    );
    const latencyMs = Date.now() - t0;
    return isHazard
      ? finalizeHazard(data, { model, latencyMs, toolTrace: inv.trace, extraLimitations: extra })
      : finalizePpe(data, { required, context, model, latencyMs, yolo: inv.yolo, toolTrace: inv.trace, imageQuality: inv.quality, extraLimitations: extra });
  } catch (err) {
    const latency = Date.now() - t0;
    return isHazard ? failureHazard(err, latency, context.category ?? 'OTHER') : failurePpe(required, err, latency);
  }
}
