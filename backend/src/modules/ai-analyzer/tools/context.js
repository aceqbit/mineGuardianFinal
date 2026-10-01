// Tools that read MongoDB. Without a connected database they return status "unavailable" (get_required_ppe falls back to the default set).
import mongoose from 'mongoose';
import { DEFAULT_REQUIRED_PPE } from '../config.js';

const connected = () => mongoose.connection?.readyState === 1;
const isId = (v) => mongoose.isValidObjectId(v) && String(v).length === 24;

export async function getRequiredPpe({ zone_id }, ctx = {}) {
  if (connected() && zone_id) {
    const Zone = mongoose.models.Zone;
    if (Zone) {
      const z = isId(zone_id) ? await Zone.findById(zone_id) : await Zone.findOne({ code: zone_id });
      if (z) {
        const required = [...z.requiredPpe];
        const all = ['HELMET', 'CAP_LAMP', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES', 'SELF_RESCUER', 'DUST_MASK', 'EAR_PROTECTION', 'EYE_PROTECTION', 'GAS_DETECTOR'];
        return { status: 'ok', zoneCode: z.code, required, notRequired: all.filter((k) => !required.includes(k)) };
      }
    }
  }
  const required = ctx.requiredPpe?.length ? ctx.requiredPpe : [...DEFAULT_REQUIRED_PPE];
  return { status: connected() ? 'ok' : 'unavailable', reason: connected() ? 'zone not found; using the zone given in the request' : 'database not connected; using the default set', zoneCode: ctx.zoneCode ?? null, required, notRequired: [] };
}

export async function verifyPhotoIntegrity({ checkin_id }) {
  if (!connected()) return { status: 'unavailable', reason: 'database not connected' };
  const CheckIn = mongoose.models.CheckIn;
  if (!CheckIn || !isId(checkin_id)) return { status: 'unavailable', reason: 'check-in not available' };
  const c = await CheckIn.findById(checkin_id);
  if (!c) return { status: 'error', reason: 'check-in not found' };
  const sent = c.queuedAt || c.uploadStartedAt;
  return {
    status: 'ok', source: c.source, capturedAt: c.capturedAt, receivedAt: c.receivedAt,
    ageAtUploadMin: c.capturedAt && sent ? Math.round((sent - c.capturedAt) / 60000) : null, clockSkewSec: c.clockSkewSec,
    integrityFlags: c.integrityFlags, accuracyM: c.accuracyM, insideZone: c.insideZone, withinShift: c.withinShift,
  };
}

export async function getWorkerHistory({ worker_id }) {
  if (!connected()) return { status: 'unavailable', reason: 'database not connected' };
  if (!isId(worker_id)) return { status: 'unavailable', reason: 'invalid worker id' };
  const since = new Date(Date.now() - 30 * 24 * 3600 * 1000);
  const wid = new mongoose.Types.ObjectId(worker_id);
  const checkIns = await mongoose.connection.collection('check_ins').countDocuments({ workerId: wid, createdAt: { $gte: since } });
  const reviews = await mongoose.connection.collection('compliance_reviews').find({ workerId: wid, status: 'DECIDED', 'decision.decidedAt': { $gte: since } }).toArray();
  const missed = new Map();
  let compliant = 0, non = 0;
  for (const r of reviews) {
    if (r.decision.finalVerdict === 'COMPLIANT') compliant++;
    else {
      non++;
      for (const i of r.decision.items ?? []) if (i.status === 'ABSENT') missed.set(i.key, (missed.get(i.key) ?? 0) + 1);
    }
  }
  const snap = await mongoose.connection.collection('score_snapshots').findOne({ workerId: wid });
  return {
    status: 'ok', checkIns, decidedCompliant: compliant, decidedNonCompliant: non,
    mostMissed: [...missed.entries()].sort((a, b) => b[1] - a[1]).map(([key, count]) => ({ key, count })), currentStreak: snap?.streak ?? 0,
  };
}
