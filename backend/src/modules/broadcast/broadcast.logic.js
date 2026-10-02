// Pure broadcast rules (CLAUDE.md §13). No I/O.
import { AppError } from '../../core/errors.js';

export const MAX_SMS_TARGETS = 20;

/** Who may send what: admin any scope; a supervisor only ZONE of their own zone. */
export function authorizeSend(user, { scope, zoneId }) {
  if (user.role === 'admin') return;
  if (user.role === 'supervisor' && scope === 'ZONE' && String(zoneId) === String(user.zoneId)) return;
  throw new AppError(403, 'FORBIDDEN_ROLE', 'Supervisors can only broadcast to their own zone');
}

/** Socket rooms for a scope. */
export function roomsFor({ scope, zoneId, role }) {
  if (scope === 'ALL') return ['*'];
  if (scope === 'ZONE') return [`zone:${zoneId}`];
  return [`role:${role}`];
}

/** Does a broadcast reach this user (used by catch-up)? */
export function reaches(b, user) {
  if (b.scope === 'ALL') return true;
  if (b.scope === 'ZONE') return String(b.zoneId) === String(user.zoneId);
  return b.role === user.role;
}

/** The people who are offline now, capped. EMERGENCY only. */
export function smsTargets(users, isOnline, cap = MAX_SMS_TARGETS) {
  return users.filter((u) => u.phone?.e164 && !isOnline(String(u._id))).slice(0, cap);
}

/** Per-id ack counters: first DELIVERED then READ; READ implies DELIVERED. */
export function applyAck(state, userId, status) {
  const id = String(userId);
  const delivered = new Set(state.delivered);
  const read = new Set(state.read);
  delivered.add(id);
  if (status === 'READ') read.add(id);
  return { delivered, read, changed: delivered.size !== state.delivered.size || read.size !== state.read.size };
}

export const smsText = (b) => `MINE GUARDIAN ${b.priority}: ${b.text}`.slice(0, 320);
