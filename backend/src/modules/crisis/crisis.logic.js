// Pure crisis rules (CLAUDE.md §13). No I/O.
import { randomBytes } from 'node:crypto';
import { AppError } from '../../core/errors.js';

const URL_SAFE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

/** 24 URL-safe random characters. */
export function newShareToken() {
  const bytes = randomBytes(24);
  let out = '';
  for (let i = 0; i < 24; i += 1) out += URL_SAFE[bytes[i] & 63];
  return out;
}

const sameTrigger = (a, b) => a.type === b.type && String(a.refId ?? '') === String(b.refId ?? '');

/**
 * Merge a new trigger into an ACTIVE crisis: union zones, add the trigger once, add a timeline line.
 * Returns {crisis, changed, line}. `crisis` is a new object.
 */
export function mergeTrigger(crisis, trigger, zoneIds = [], reason = '', now = new Date()) {
  const triggers = [...(crisis.triggers ?? [])];
  const zones = [...new Set([...(crisis.zoneIds ?? []).map(String), ...zoneIds.map(String)])];
  const isNewTrigger = !triggers.some((t) => sameTrigger(t, trigger));
  const addedZones = zones.filter((z) => !(crisis.zoneIds ?? []).map(String).includes(z));
  if (!isNewTrigger && !addedZones.length) return { crisis, changed: false, line: null };
  if (isNewTrigger) triggers.push({ ...trigger, at: now });
  const line = { at: now, text: `${isNewTrigger ? `Additional trigger: ${trigger.type}` : 'Zones added'}${reason ? ` — ${reason}` : ''}${addedZones.length ? ` (+${addedZones.length} zone)` : ''}` };
  return { crisis: { ...crisis, triggers, zoneIds: zones, timeline: [...(crisis.timeline ?? []), line] }, changed: true, line };
}

/** Resolve rules: a real crisis needs both checklist items true and a note >= 10 chars. */
export function validateResolve(body) {
  const note = (body?.note ?? '').trim();
  if (note.length < 10) throw new AppError(400, 'VALIDATION_ERROR', 'A resolution note of at least 10 characters is required', [{ path: 'note', message: 'Too short' }]);
  if (!body.falseAlarm && !(body.checklist?.allAccounted === true && body.checklist?.hazardsContained === true)) {
    throw new AppError(400, 'CHECKLIST_INCOMPLETE', 'Confirm everyone is accounted for and hazards are contained, or mark a false alarm');
  }
  return { falseAlarm: Boolean(body.falseAlarm), note, checklist: { allAccounted: Boolean(body.checklist?.allAccounted), hazardsContained: Boolean(body.checklist?.hazardsContained) } };
}

/** Accounted-for counts over a roster [{status}]. */
export function accountedCounts(roster) {
  const c = { SAFE: 0, MISSING: 0, INJURED: 0, UNKNOWN: 0 };
  for (const r of roster) c[r.status] = (c[r.status] ?? 0) + 1;
  return { ...c, total: roster.length };
}

/** Roster for the crisis zones: every miner gets their recorded status, default UNKNOWN. */
export function buildRoster(miners, accounted = []) {
  const byWorker = new Map(accounted.map((a) => [String(a.workerId), a]));
  return miners.map((m) => ({
    userId: String(m._id), name: m.fullName, employeeId: m.employeeId, zoneId: String(m.zoneId),
    status: byWorker.get(String(m._id))?.status ?? 'UNKNOWN',
  }));
}

/** Upsert one accounted entry (SosCancelled, supervisor update). */
export function setAccounted(accounted, workerId, status, by = null, at = new Date()) {
  const rest = accounted.filter((a) => String(a.workerId) !== String(workerId));
  return [...rest, { workerId, status, by, at }];
}

/** Voice and SMS texts. Limits: voice <= 450, SMS <= 320 characters. */
export function crisisTexts({ reason, zoneCodes, trackUrl }) {
  const zones = zoneCodes.join(', ');
  const voice = `Mine Guardian emergency. ${reason || 'A crisis has been declared'}. Zones affected: ${zones}. Open the Mine Guardian app now for evacuation routes.`.slice(0, 450);
  const sms = `MINE GUARDIAN EMERGENCY: ${reason || 'Crisis declared'}. Zones: ${zones}. Track: ${trackUrl}`.slice(0, 320);
  return { voice, sms };
}
