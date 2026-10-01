// Two-stage agent. Stage A investigates with tools (function calling). Stage B is a fresh single-turn request with no tools and
// the evidence dossier, returning schema-locked JSON; this avoids mixing tools and structured output in one call.
import { TIMEOUTS } from './config.js';
import { generateContent, inlineImagePart } from './gemini.client.js';
import { FUNCTION_DECLARATIONS, runTool } from './tools/index.js';
import { SYSTEM_CORE, STAGE_A_SUFFIX, taskHazard, taskPpe } from './prompts.js';

const MAX_ROUNDS = 4;

export async function investigate({ img, isHazard, context, cfg, required }) {
  const t0 = Date.now();
  const trace = [];
  const cache = new Map();
  const toolCtx = { img, cfg, context };
  let stageAError = null;
  let stageANotes = '';

  const exec = async (name, args, calledBy) => {
    const key = `${name}:${JSON.stringify(args ?? {})}`;
    if (cache.has(key)) return cache.get(key); // repeats are free
    const s = Date.now();
    const result = await runTool(name, args, toolCtx);
    trace.push({ name, ms: Date.now() - s, status: result.status, calledBy });
    cache.set(key, result);
    return result;
  };

  // ---- Stage A (model-driven) ----
  if (cfg.mlMode !== 'yolo_only' && cfg.apiKey) {
    try {
      const task = isHazard ? taskHazard(context) : taskPpe({ ...context, requiredPpe: required });
      const contents = [{ role: 'user', parts: [inlineImagePart(img.base64), { text: `${task}\n\n${STAGE_A_SUFFIX}` }] }];
      for (let round = 0; round < MAX_ROUNDS; round++) {
        if (Date.now() - t0 > TIMEOUTS.stageABudgetMs) break; // over the Stage A budget: go to Stage B
        const config = {
          systemInstruction: SYSTEM_CORE,
          tools: [{ functionDeclarations: FUNCTION_DECLARATIONS }],
          toolConfig: { functionCallingConfig: { mode: round === 0 ? 'ANY' : 'AUTO' } },
        };
        const { res } = await generateContent({ contents, config }, cfg);
        const calls = res.functionCalls ?? [];
        if (!calls.length) {
          stageANotes = typeof res.text === 'string' ? res.text : '';
          break;
        }
        contents.push(res.candidates[0].content); // pushed back UNCHANGED: it may carry thought signatures
        const results = await Promise.all(calls.map((c) => exec(c.name, c.args ?? {}, 'model')));
        contents.push({ role: 'user', parts: calls.map((c, i) => ({ functionResponse: { name: c.name, response: { output: results[i] } } })) });
      }
    } catch (e) {
      stageAError = String(e.message ?? e).slice(0, 200);
    }
  }

  // ---- Mandatory-tool guardrail: run server-side anything the model skipped ----
  const mandatory = ['detect_ppe_yolo', 'analyze_image_quality'];
  if (!isHazard) mandatory.push('get_required_ppe');
  if (!isHazard && context.checkInId) mandatory.push('verify_photo_integrity');
  if (isHazard) mandatory.push('get_hazard_protocol');
  await Promise.all(mandatory.map((name) => {
    const args = name === 'get_required_ppe' ? { zone_id: context.zoneCode } : name === 'verify_photo_integrity' ? { checkin_id: context.checkInId } : name === 'get_hazard_protocol' ? { category: context.category } : {};
    return exec(name, args, [...cache.keys()].some((k) => k.startsWith(`${name}:`)) ? 'model' : 'server');
  }));

  const get = (name) => [...cache.entries()].find(([k]) => k.startsWith(`${name}:`))?.[1] ?? null;
  const yolo = get('detect_ppe_yolo');
  const quality = get('analyze_image_quality');
  const integrity = get('verify_photo_integrity');
  const history = get('get_worker_history');
  const protocol = get('get_hazard_protocol');
  const requiredInfo = get('get_required_ppe');

  const topYolo = yolo && yolo.status === 'ok' ? { ...yolo, detections: [...yolo.detections].sort((a, b) => b.confidence - a.confidence).slice(0, 30) } : yolo;
  const dossier = { yolo: topYolo, imageQuality: quality, requiredPpe: requiredInfo, integrity, workerHistory: history, hazardProtocol: protocol };
  const unavailable = Object.entries({ yolo, quality, integrity }).filter(([, v]) => v && v.status !== 'ok').map(([k]) => k);

  return { dossier, yolo, quality, integrity, trace, stageANotes: stageANotes.slice(0, 2000), stageAError, unavailable, ms: Date.now() - t0 };
}
