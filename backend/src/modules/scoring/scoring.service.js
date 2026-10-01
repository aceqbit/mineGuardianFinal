import { SHIFT_HOURS } from '../../contracts/enums.js';
import { emitTo } from '../../core/socket.js';
import { logger } from '../../core/logger.js';
import { AppError } from '../../core/errors.js';
import { CheckIn } from '../../models/CheckIn.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { Hazard } from '../../models/Hazard.js';
import { ScoreSnapshot } from '../../models/ScoreSnapshot.js';
import { User } from '../../models/User.js';
import { istDateString } from '../checkins/integrity.js';
import { WINDOW_DAYS, computeScore, rankRows, windowDays } from './score.formula.js';

const IST_MS = 5.5 * 3_600_000;
const CRITICAL_MISSING = ['HELMET', 'SELF_RESCUER', 'CAP_LAMP'];

/** Minutes between the shift start and `at` (IST). Night shift C starts 22:00, so an early-morning `at` is measured from the previous evening. */
export function minutesAfterShiftStart(shift, at) {
  const hours = SHIFT_HOURS[shift];
  if (!hours || !at) return null;
  const ist = new Date(new Date(at).getTime() + IST_MS);
  const minOfDay = ist.getUTCHours() * 60 + ist.getUTCMinutes();
  const [h, m] = hours[0].split(':').map(Number);
  let start = h * 60 + m;
  if (shift === 'C' && minOfDay < start - 12 * 60) start -= 24 * 60;
  return minOfDay - start;
}

/** Collapse a worker's decided reviews into one entry per IST day (the latest decision of the day wins). */
export function buildDayMap(rows) {
  const map = {};
  for (const { review, checkIn, shift } of rows) {
    const at = checkIn.capturedAt ?? checkIn.receivedAt ?? checkIn.createdAt;
    const day = istDateString(at);
    const decidedAt = new Date(review.decision?.decidedAt ?? 0).getTime();
    if (map[day] && map[day]._t > decidedAt) continue;
    const items = review.decision?.items ?? [];
    const missing = items.filter((i) => i.status === 'ABSENT').map((i) => i.key);
    map[day] = {
      _t: decidedAt,
      verdict: review.decision?.finalVerdict,
      firstPass: (checkIn.attempt ?? 1) === 1,
      minutesAfterStart: minutesAfterShiftStart(shift, at),
      missing,
      frozen: Boolean(review.sla?.streakFrozen) && !review.sla?.compensated,
      critical: review.ai?.criticality?.level === 'CRITICAL' || missing.some((k) => CRITICAL_MISSING.includes(k)),
    };
  }
  return map;
}

export async function loadWorkerInputs(user, now) {
  const today = istDateString(now);
  const since = new Date(`${windowDays(today)[0]}T00:00:00+05:30`);
  const checkIns = await CheckIn.find({ workerId: user._id, createdAt: { $gte: since } });
  const byId = new Map(checkIns.map((c) => [String(c._id), c]));
  const reviews = await ComplianceReview.find({ workerId: user._id, status: 'DECIDED', checkInId: { $in: [...byId.keys()] } });
  const rows = reviews.map((r) => ({ review: r, checkIn: byId.get(String(r.checkInId)), shift: user.shift })).filter((r) => r.checkIn);
  const hz = await Hazard.find({ reporterId: user._id, status: { $in: ['CLOSED', 'REJECTED'] }, updatedAt: { $gte: since } });
  const hazards = hz.map((h) => ({
    day: istDateString(h.closedAt ?? h.updatedAt),
    kind: h.status === 'CLOSED' ? 'CLOSED' : 'REJECTED',
    severity: h.ai?.severity ?? null,
  }));
  return { today, days: buildDayMap(rows), hazards };
}

/** Recompute and persist one worker's score for today (IST). Emits score:updated. */
export async function recomputeWorker(userOrId, { now = new Date(), notify = true } = {}) {
  const user = userOrId?._id ? userOrId : await User.findById(userOrId);
  if (!user || user.role !== 'miner') return null;
  const { today, days, hazards } = await loadWorkerInputs(user, now);
  const prev = await ScoreSnapshot.findOne({ userId: user._id }).sort({ day: -1 });
  const res = computeScore({ today, days, hazards, priorBadges: prev?.badges ?? [], now });
  const snap = await ScoreSnapshot.findOneAndUpdate(
    { userId: user._id, day: today },
    { $set: { zoneId: user.zoneId, ...res, computedAt: now } },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );
  if (notify) {
    emitTo([`user:${user._id}`], 'score:updated', { score: res.score, streak: res.streak, xp: res.xp, badges: res.badges.map((b) => b.key) });
    scheduleLeaderboardEmit();
  }
  return snap;
}

export async function recomputeAll(now = new Date()) {
  const miners = await User.find({ role: 'miner', status: 'active' });
  let n = 0;
  for (const u of miners) {
    try {
      await recomputeWorker(u, { now, notify: false });
      n += 1;
    } catch (err) {
      logger.error({ err: err.message, userId: String(u._id) }, 'score recompute failed');
    }
  }
  scheduleLeaderboardEmit();
  return n;
}

/** Latest snapshot per active miner; `asOfDay` limits to snapshots on or before that IST day (used for month-end rankings). */
export async function latestSnapshots(filter = {}, asOfDay = null) {
  const miners = await User.find({ role: 'miner', status: 'active', ...filter });
  const snaps = await ScoreSnapshot.aggregate([
    { $match: { userId: { $in: miners.map((m) => m._id) }, ...(asOfDay ? { day: { $lte: asOfDay } } : {}) } },
    { $sort: { day: -1 } },
    { $group: { _id: '$userId', doc: { $first: '$$ROOT' } } },
  ]);
  const byUser = new Map(snaps.map((s) => [String(s._id), s.doc]));
  return miners.map((m) => ({ miner: m, snap: byUser.get(String(m._id)) }));
}

const row = (m, s) => ({ userId: String(m._id), name: m.fullName, employeeId: m.employeeId, zoneId: String(m.zoneId), score: s?.score ?? 0, streak: s?.streak ?? 0, xp: s?.xp ?? 0 });

/** Public leaderboard: top N, never includes risk bands (miners must not see them). */
export async function leaderboard({ limit = 50, zoneId } = {}) {
  const rows = (await latestSnapshots(zoneId ? { zoneId } : {})).map(({ miner, snap }) => row(miner, snap));
  return rankRows(rows).slice(0, limit);
}

export async function myStanding(user) {
  const rows = rankRows((await latestSnapshots()).map(({ miner, snap }) => row(miner, snap)));
  const mine = rows.find((r) => r.userId === String(user._id));
  const snap = await ScoreSnapshot.findOne({ userId: user._id }).sort({ day: -1 });
  const above = mine && mine.rank > 1 ? rows.find((r) => r.rank < mine.rank && r.score > mine.score) : null;
  return {
    rank: mine?.rank ?? null,
    total: rows.length,
    score: snap?.score ?? 0,
    streak: snap?.streak ?? 0,
    xp: snap?.xp ?? 0,
    badges: (snap?.badges ?? []).map((b) => ({ key: b.key, earnedAt: b.earnedAt })),
    components: snap?.components ?? {},
    gapToNext: above ? above.score - mine.score : 0,
  };
}

/** Risk bands for one zone: supervisors and admins only. */
export async function zoneScores(user, zoneId) {
  if (user.role === 'supervisor' && String(user.zoneId) !== String(zoneId)) throw new AppError(403, 'FORBIDDEN_ROLE', 'You can only view your own zone');
  return (await latestSnapshots({ zoneId })).map(({ miner, snap }) => ({
    workerId: String(miner._id),
    fullName: miner.fullName,
    employeeId: miner.employeeId,
    score: snap?.score ?? 0,
    streak: snap?.streak ?? 0,
    riskBand: snap?.riskBand ?? 'GREEN',
  }));
}

/** Supervisor responsiveness: share of reviews decided inside the SLA over the last 30 days. */
export async function supervisorBoard(now = new Date()) {
  const since = new Date(now.getTime() - WINDOW_DAYS * 86_400_000);
  const sups = await User.find({ role: 'supervisor', status: 'active' });
  const reviews = await ComplianceReview.find({ status: 'DECIDED', 'decision.decidedAt': { $gte: since } });
  const rows = sups.map((s) => {
    const mine = reviews.filter((r) => String(r.decision?.decidedBy) === String(s._id));
    const onTime = mine.filter((r) => r.sla?.dueAt && new Date(r.decision.decidedAt) <= new Date(r.sla.dueAt)).length;
    return { userId: String(s._id), name: s.fullName, employeeId: s.employeeId, zoneId: String(s.zoneId), decided: mine.length, onTime, score: mine.length ? Math.round((1000 * onTime) / mine.length) : 0, streak: 0, xp: mine.length };
  });
  return rankRows(rows);
}

let lastEmit = 0;
let pending = null;
/** leaderboard:updated is throttled to one per 2 s (trailing edge). */
export function scheduleLeaderboardEmit() {
  if (pending) return;
  const wait = Math.max(0, lastEmit + 2000 - Date.now());
  pending = setTimeout(async () => {
    pending = null;
    lastEmit = Date.now();
    try {
      emitTo(['public:leaderboard'], 'leaderboard:updated', { top: await leaderboard() });
    } catch (err) {
      logger.error({ err: err.message }, 'leaderboard emit failed');
    }
  }, wait);
  pending.unref?.();
}
