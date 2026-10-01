import { GoogleGenAI } from '@google/genai';
import { aiConfig, TIMEOUTS } from './config.js';
import { AiBlockedError, AiError } from './image.prep.js';

let client;
let clientKey;

export function getClient(cfg = aiConfig()) {
  if (!cfg.apiKey) throw new AiError('NO_API_KEY', 'GEMINI_API_KEY is not set');
  if (!client || clientKey !== cfg.apiKey) {
    client = new GoogleGenAI({ apiKey: cfg.apiKey });
    clientKey = cfg.apiKey;
  }
  return client;
}

/** Dangerous-content filter is relaxed so injury and fire photos are not blocked; the rest stay on. */
export const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function withTimeout(promise, ms, label = 'call') {
  let t;
  const timeout = new Promise((_, rej) => {
    t = setTimeout(() => rej(Object.assign(new Error(`${label} timed out after ${ms} ms`), { code: 'TIMEOUT' })), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(t));
}

const statusOf = (e) => Number(e?.status ?? e?.code ?? e?.error?.code ?? (/\b(429|500|503)\b/.exec(e?.message ?? '') || [])[1]) || null;
export const isRetryable = (e) => e?.code === 'TIMEOUT' || [429, 500, 503].includes(statusOf(e));
export const isModelNotFound = (e) => statusOf(e) === 404 || /not found|is not supported|unknown model/i.test(e?.message ?? '');

/** One generateContent call on one model, with retries (1 s then 3 s) on 429 / 500 / 503 / timeout. */
async function callWithRetry({ model, contents, config }, cfg) {
  let lastErr;
  for (let attempt = 0; attempt <= TIMEOUTS.retries; attempt++) {
    try {
      return await withTimeout(getClient(cfg).models.generateContent({ model, contents, config }), TIMEOUTS.callMs, `Gemini ${model}`);
    } catch (e) {
      lastErr = e;
      if (!isRetryable(e) || attempt === TIMEOUTS.retries) break;
      await sleep(TIMEOUTS.retryDelaysMs[attempt] ?? 3000);
    }
  }
  throw lastErr;
}

/** Primary model first; on 404 / "model not found" or exhausted retries, once on the fallback model. Records which model answered. */
export async function generateContent({ contents, config }, cfg = aiConfig()) {
  const full = { safetySettings: SAFETY_SETTINGS, maxOutputTokens: 4096, ...(cfg.temperature !== undefined ? { temperature: cfg.temperature } : {}), ...config };
  try {
    const res = await callWithRetry({ model: cfg.model, contents, config: full }, cfg);
    return { res, model: cfg.model };
  } catch (e) {
    if (cfg.fallbackModel && cfg.fallbackModel !== cfg.model && (isModelNotFound(e) || isRetryable(e))) {
      const res = await callWithRetry({ model: cfg.fallbackModel, contents, config: full }, cfg);
      return { res, model: cfg.fallbackModel };
    }
    throw e;
  }
}

/** Throws AiBlockedError for blocked / empty output. Returns the text. */
export function textOrThrow(res) {
  const block = res?.promptFeedback?.blockReason;
  if (block) throw new AiBlockedError(`Blocked by safety filter: ${block}`);
  const cand = res?.candidates?.[0];
  if (cand?.finishReason && ['SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII'].includes(cand.finishReason)) throw new AiBlockedError(`Blocked: ${cand.finishReason}`);
  const text = (typeof res?.text === 'string' ? res.text : cand?.content?.parts?.map((p) => p.text ?? '').join('')) ?? '';
  if (!text.trim()) throw new AiBlockedError('Empty model output');
  return text;
}

const stripFence = (t) => t.replace(/^\s*```(?:json)?\s*/i, '').replace(/\s*```\s*$/i, '').trim();

/**
 * generateJson({ systemInstruction, parts, schema, zodSchema }) -> { data, model, latencyMs }.
 * Parses and zod-validates; on a validation failure makes ONE repair call that quotes the issues.
 */
export async function generateJson({ systemInstruction, parts, schema, zodSchema }, cfg = aiConfig()) {
  const t0 = Date.now();
  const config = { systemInstruction, responseMimeType: 'application/json', responseJsonSchema: schema };
  const contents = [{ role: 'user', parts }];
  const { res, model } = await generateContent({ contents, config }, cfg);
  const raw = textOrThrow(res);
  const attempt = (txt) => {
    const parsed = JSON.parse(stripFence(txt));
    return zodSchema.parse(parsed);
  };
  try {
    return { data: attempt(raw), model, latencyMs: Date.now() - t0 };
  } catch (firstErr) {
    const issues = firstErr?.issues ? JSON.stringify(firstErr.issues.slice(0, 8)) : String(firstErr?.message ?? firstErr);
    const repairContents = [
      ...contents,
      { role: 'model', parts: [{ text: raw.slice(0, 6000) }] },
      { role: 'user', parts: [{ text: `Your previous JSON failed validation: ${issues}\nReturn corrected JSON only, matching the response schema exactly.` }] },
    ];
    const { res: res2, model: model2 } = await generateContent({ contents: repairContents, config }, cfg);
    return { data: attempt(textOrThrow(res2)), model: model2, latencyMs: Date.now() - t0 };
  }
}

export function inlineImagePart(base64, mimeType = 'image/jpeg') {
  return { inlineData: { mimeType, data: base64 } };
}
