import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { sendToUsers } from '../../core/fcm.js';
import { logger } from '../../core/logger.js';
import { Reward } from '../../models/Reward.js';
import { User } from '../../models/User.js';
import { istDateString } from '../checkins/integrity.js';
import { latestSnapshots } from '../scoring/scoring.service.js';
import { rankRows } from '../scoring/score.formula.js';

/** Demo values only. The UI labels every amount "demo value". */
export const HONOUR_TIERS = [
  { rank: 1, title: 'Safety Champion', stars: 3, amountInr: 2000, extraHolidays: 1 },
  { rank: 2, title: 'Safety Runner-up', stars: 2, amountInr: 1000, extraHolidays: 0 },
  { rank: 3, title: 'Safety Merit', stars: 1, amountInr: 500, extraHolidays: 0 },
];

export const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export const currentMonth = (now = new Date()) => istDateString(now).slice(0, 7);

export function previousMonth(now = new Date()) {
  const [y, m] = currentMonth(now).split('-').map(Number);
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
}

export function lastDayOf(month) {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
}

/** Pure: who earns an honour from a set of leaderboard rows. Zero-score workers never earn one. */
export function pickHonours(rows) {
  const ranked = rankRows(rows.filter((r) => r.score > 0));
  const out = [];
  for (const tier of HONOUR_TIERS) {
    for (const r of ranked.filter((x) => x.rank === tier.rank)) out.push({ ...tier, row: r });
  }
  return out;
}

/** Idempotent: re-running a month inserts nothing new (unique month+userId+key). */
export async function publishMonth(month, { actor = null, now = new Date() } = {}) {
  if (!MONTH_RE.test(month)) throw new AppError(400, 'VALIDATION_ERROR', 'month must be YYYY-MM', [{ path: 'month', message: 'Invalid' }]);
  if (month > currentMonth(now)) throw new AppError(400, 'VALIDATION_ERROR', 'Cannot publish a future month', [{ path: 'month', message: 'In the future' }]);
  const asOf = month === currentMonth(now) ? istDateString(now) : lastDayOf(month);
  const snaps = await latestSnapshots({}, asOf);
  const rows = snaps.map(({ miner, snap }) => ({ userId: String(miner._id), zoneId: miner.zoneId, name: miner.fullName, score: snap?.score ?? 0, streak: snap?.streak ?? 0, xp: snap?.xp ?? 0 }));
  const honours = pickHonours(rows);
  const created = [];
  for (const h of honours) {
    const key = `HONOUR_RANK_${h.rank}`;
    const res = await Reward.updateOne(
      { month, userId: h.row.userId, key },
      { $setOnInsert: { zoneId: h.row.zoneId, kind: 'HONOUR', title: h.title, rank: h.row.rank, score: h.row.score, stars: h.stars, amountInr: h.amountInr, extraHolidays: h.extraHolidays, demo: true, publishedAt: now } },
      { upsert: true },
    );
    if (res.upsertedCount) created.push(h.row.userId);
  }
  if (created.length) {
    sendToUsers(created, { title: 'Monthly safety honour', body: `You earned a safety honour for ${month}. Open Rewards to see it.`, data: { type: 'reward', month } }).catch((err) => logger.warn({ err: err.message }, 'reward push failed'));
  }
  await audit(actor, 'REWARDS_PUBLISHED', 'reward', month, { created: created.length, total: honours.length });
  return { month, created: created.length, existing: honours.length - created.length };
}

/** Miners see their own honours; staff see everyone's for the month. */
export async function listRewards(user, month) {
  const filter = { ...(month ? { month } : {}), ...(user.role === 'miner' ? { userId: user._id } : {}) };
  const rewards = await Reward.find(filter).sort({ month: -1, rank: 1 });
  const users = await User.find({ _id: { $in: rewards.map((r) => r.userId) } });
  const names = new Map(users.map((u) => [String(u._id), u]));
  const months = (await Reward.distinct('month', user.role === 'miner' ? { userId: user._id } : {})).sort().reverse();
  return {
    months,
    rewards: rewards.map((r) => ({
      ...r.toJSON(),
      userId: String(r.userId),
      workerName: names.get(String(r.userId))?.fullName ?? '',
      employeeId: names.get(String(r.userId))?.employeeId ?? '',
    })),
  };
}
