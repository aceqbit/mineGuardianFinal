import mongoose from 'mongoose';
import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { logger } from '../../core/logger.js';
import { emitTo, isOnline } from '../../core/socket.js';
import { sendSms } from '../../core/twilio.js';
import { Broadcast } from '../../models/Broadcast.js';
import { BroadcastReply } from '../../models/BroadcastReply.js';
import { User } from '../../models/User.js';
import { addTimeline, getActive } from '../crisis/crisis.engine.js';
import { applyAck, authorizeSend, reaches, roomsFor, smsTargets, smsText } from './broadcast.logic.js';

const ACK_FLUSH_MS = 5000;
const STATS_THROTTLE_MS = 1000;

/** broadcastId -> {delivered:Set, read:Set, targets, senderId, dirty, lastStats} */
const counters = new Map();
let flushTimer = null;

async function targetUsers({ scope, zoneId, role }) {
  const filter = { status: 'active', ...(scope === 'ZONE' ? { zoneId } : scope === 'ROLE' ? { role } : {}) };
  return User.find(filter).select('phone.e164 role zoneId');
}

const payloadOf = (b) => ({ id: String(b._id), text: b.text, priority: b.priority, scope: b.scope, zoneId: b.zoneId ? String(b.zoneId) : null, role: b.role ?? null, senderName: b.senderName, senderRole: b.senderRole, createdAt: b.createdAt.toISOString() });

/** Emit first (the id is generated up front), persist after, then SMS the offline for EMERGENCY. */
export async function sendBroadcast(user, body) {
  authorizeSend(user, body);
  const _id = new mongoose.Types.ObjectId();
  const createdAt = new Date();
  const doc = { _id, text: body.text, priority: body.priority, scope: body.scope, zoneId: body.scope === 'ZONE' ? body.zoneId : undefined, role: body.scope === 'ROLE' ? body.role : undefined, senderId: user._id, senderName: user.fullName, senderRole: user.role, createdAt };
  const msg = payloadOf({ ...doc });
  emitTo(roomsFor(body), 'broadcast:message', msg);
  const crisis = getActive();
  setImmediate(async () => {
    try {
      const users = await targetUsers(body);
      const targets = users.filter((u) => String(u._id) !== String(user._id));
      let smsSent = 0;
      if (body.priority === 'EMERGENCY') {
        const offline = smsTargets(targets, isOnline);
        const results = await Promise.allSettled(offline.map((u) => sendSms(u.phone.e164, smsText(doc))));
        smsSent = results.filter((r) => r.status === 'fulfilled' && !r.value?.error).length;
      }
      await Broadcast.create({ ...doc, targetCount: targets.length, smsSent, crisisId: crisis?._id });
      counters.set(String(_id), { delivered: new Set(), read: new Set(), targets: targets.length, senderId: String(user._id), dirty: false, lastStats: 0 });
      if (crisis) addTimeline(`Broadcast (${body.priority}) by ${user.fullName}: ${body.text.slice(0, 60)}`);
      await audit(user, 'BROADCAST_SENT', 'broadcast', _id, { scope: body.scope, priority: body.priority, targets: targets.length, smsSent });
    } catch (err) {
      logger.error({ err: err.message }, 'broadcast persist failed');
    }
  });
  return msg;
}

/** Catch-up for a client that was offline: broadcasts since `since` that reach this user, newest last, max 50. */
export async function catchUp(user, since) {
  const from = since ? new Date(since) : new Date(Date.now() - 24 * 3_600_000);
  const rows = await Broadcast.find({ createdAt: { $gt: from } }).sort({ createdAt: -1 }).limit(200);
  return rows.filter((b) => reaches(b, user)).slice(0, 50).reverse().map(payloadOf);
}

/** The sender's (or an admin's) own history with live counters for the composer screen. */
export async function history(user) {
  const rows = await Broadcast.find(user.role === 'admin' ? {} : { senderId: user._id }).sort({ createdAt: -1 }).limit(30);
  return rows.map((b) => ({ ...payloadOf(b), targets: b.targetCount, delivered: b.deliveredBy.length, read: b.readBy.length, replies: b.replyCount, smsSent: b.smsSent }));
}

export async function repliesFor(user, broadcastId) {
  const filter = broadcastId ? { broadcastId } : {};
  if (broadcastId && user.role !== 'admin') {
    const b = await Broadcast.findById(broadcastId);
    if (!b || String(b.senderId) !== String(user._id)) throw new AppError(403, 'FORBIDDEN_ROLE', 'Not your broadcast');
  }
  const rows = await BroadcastReply.find(user.role === 'admin' ? filter : { ...filter, broadcastId: { $in: (await Broadcast.find({ senderId: user._id }).select('_id')).map((b) => b._id) } }).sort({ createdAt: -1 }).limit(100);
  return rows.map((r) => ({ id: String(r._id), broadcastId: r.broadcastId ? String(r.broadcastId) : null, userId: String(r.userId), userName: r.userName, text: r.text, at: r.createdAt.toISOString() }));
}

let lastStatsEmit = new Map();
function emitStats(id, c) {
  const now = Date.now();
  if (now - (lastStatsEmit.get(id) ?? 0) < STATS_THROTTLE_MS) return;
  lastStatsEmit.set(id, now);
  emitTo(['role:admin', `user:${c.senderId}`], 'broadcast:stats', { broadcastId: id, targets: c.targets, delivered: c.delivered.size, read: c.read.size });
}

/** Socket handler: broadcast:ack {broadcastId, status:DELIVERED|READ}. Counters flush to Mongo every 5 s. */
export async function handleAck(ctx, data) {
  const { broadcastId, status } = data ?? {};
  if (!mongoose.isValidObjectId(broadcastId) || !['DELIVERED', 'READ'].includes(status)) return { ok: false, error: 'INVALID' };
  let c = counters.get(String(broadcastId));
  if (!c) {
    const b = await Broadcast.findById(broadcastId);
    if (!b) return { ok: false, error: 'NOT_FOUND' };
    c = { delivered: new Set(b.deliveredBy.map(String)), read: new Set(b.readBy.map(String)), targets: b.targetCount, senderId: String(b.senderId), dirty: false, lastStats: 0 };
    counters.set(String(broadcastId), c);
  }
  const r = applyAck({ delivered: c.delivered, read: c.read }, ctx.user._id, status);
  if (r.changed) {
    c.delivered = r.delivered;
    c.read = r.read;
    c.dirty = true;
    emitStats(String(broadcastId), c);
  }
  return { ok: true };
}

export async function flushAcks() {
  for (const [id, c] of counters) {
    if (!c.dirty) continue;
    c.dirty = false;
    await Broadcast.updateOne({ _id: id }, { $set: { deliveredBy: [...c.delivered], readBy: [...c.read] } }).catch((err) => {
      c.dirty = true;
      logger.warn({ err: err.message }, 'broadcast ack flush failed');
    });
  }
}

export function startAckFlusher() {
  flushTimer = setInterval(() => flushAcks().catch(() => null), ACK_FLUSH_MS);
  flushTimer.unref?.();
}

export const stopAckFlusher = () => clearInterval(flushTimer);

/** Socket handler: broadcast:reply {broadcastId?, text}. Goes to admins and the original sender. */
export async function handleReply(ctx, data) {
  const text = String(data?.text ?? '').trim();
  if (!text || text.length > 280) return { ok: false, error: 'INVALID_TEXT' };
  const broadcastId = mongoose.isValidObjectId(data?.broadcastId) ? data.broadcastId : undefined;
  const b = broadcastId ? await Broadcast.findById(broadcastId) : null;
  const reply = await BroadcastReply.create({ broadcastId, userId: ctx.user._id, userName: ctx.user.fullName, zoneId: ctx.user.zoneId, text });
  if (b) await Broadcast.updateOne({ _id: b._id }, { $inc: { replyCount: 1 } });
  emitTo(['role:admin', ...(b ? [`user:${b.senderId}`] : [])], 'broadcast:reply', { id: String(reply._id), broadcastId: broadcastId ? String(broadcastId) : null, userId: String(ctx.user._id), userName: ctx.user.fullName, text, at: reply.createdAt.toISOString() });
  return { ok: true };
}
