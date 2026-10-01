// Demo history: 45 days of decided check-ins for every seeded miner, daily score snapshots, and last month's honours.
// Idempotent (keyed by clientId / checkInId / user+day). Needs a seeded database: `npm run seed` first.
import { env } from '../src/config/env.js';
import { connectDb, disconnectDb } from '../src/core/db.js';
import { CheckIn } from '../src/models/CheckIn.js';
import { ComplianceReview } from '../src/models/ComplianceReview.js';
import { User } from '../src/models/User.js';
import { Zone } from '../src/models/Zone.js';
import { istDateString } from '../src/modules/checkins/integrity.js';
import { recomputeWorker } from '../src/modules/scoring/scoring.service.js';
import { previousMonth, publishMonth } from '../src/modules/rewards/rewards.service.js';
import { SHIFT_HOURS } from '../src/contracts/enums.js';

const DAYS = 45;
const DAY_MS = 86_400_000;

/** Small deterministic PRNG so every run builds the same history. */
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

// Per-miner discipline (probability of a compliant day). Spread so the leaderboard has a visible order.
const RELIABILITY = [0.98, 0.95, 0.92, 0.9, 0.85, 0.8, 0.75, 0.7, 0.9, 0.6, 0.88, 0.5];

async function main() {
  await connectDb(env.MONGODB_URI);
  const miners = await User.find({ role: 'miner', status: 'active' }).sort({ employeeId: 1 });
  if (!miners.length) throw new Error('No miners found. Run `npm run seed` first.');
  const zones = new Map((await Zone.find()).map((z) => [String(z._id), z]));
  const now = new Date();
  let made = 0;

  for (const [mi, m] of miners.entries()) {
    const rand = rng(1000 + mi);
    const zone = zones.get(String(m.zoneId));
    const required = zone?.requiredPpe ?? ['HELMET'];
    const [startH, startM] = SHIFT_HOURS[m.shift ?? 'A'][0].split(':').map(Number);
    for (let back = DAYS; back >= 1; back -= 1) {
      const dayDate = new Date(now.getTime() - back * DAY_MS);
      const day = istDateString(dayDate);
      if (new Date(`${day}T00:00:00Z`).getUTCDay() === 0) continue;
      const compliant = rand() < RELIABILITY[mi % RELIABILITY.length];
      const lateMin = Math.floor(rand() * 40);
      const capturedAt = new Date(new Date(`${day}T00:00:00+05:30`).getTime() + (startH * 60 + startM + lateMin) * 60_000);
      const missing = compliant ? [] : [required[Math.floor(rand() * required.length)]];
      const clientId = `demo-${m.employeeId}-${day}`;
      const ci = await CheckIn.findOneAndUpdate(
        { clientId },
        { $setOnInsert: { workerId: m._id, zoneId: m.zoneId, shift: m.shift, clientId, storagePath: `demo/${clientId}.jpg`, source: 'camera', attempt: rand() < 0.85 ? 1 : 2, capturedAt, receivedAt: capturedAt, status: 'REVIEWED', createdAt: capturedAt } },
        { upsert: true, new: true, setDefaultsOnInsert: true, timestamps: false },
      );
      const items = required.map((k) => ({ key: k, status: missing.includes(k) ? 'ABSENT' : 'PRESENT' }));
      await ComplianceReview.findOneAndUpdate(
        { checkInId: ci._id },
        {
          $setOnInsert: {
            workerId: m._id,
            zoneId: m.zoneId,
            status: 'DECIDED',
            ai: { overallVerdict: compliant ? 'COMPLIANT' : 'NON_COMPLIANT', overallConfidence: 0.9, items: items.map((i) => ({ ...i, required: true, confidence: 0.9, evidence: 'demo history', source: 'both' })), criticality: { level: compliant ? 'NONE' : 'MEDIUM', score: compliant ? 0 : 50, drivers: [] } },
            decision: { action: 'CONFIRM', finalVerdict: compliant ? 'COMPLIANT' : 'NON_COMPLIANT', items, note: '', decidedAt: new Date(capturedAt.getTime() + 10 * 60_000), agreedWithAi: true },
            sla: { dueAt: new Date(capturedAt.getTime() + 30 * 60_000) },
          },
        },
        { upsert: true, timestamps: false },
      );
      made += 1;
    }
    // One snapshot per past day so month-end rankings exist.
    for (let back = DAYS; back >= 0; back -= 1) {
      await recomputeWorker(m, { now: new Date(now.getTime() - back * DAY_MS), notify: false });
    }
  }
  const res = await publishMonth(previousMonth(now), { actor: null, now });
  console.log(`Demo history: ${made} check-ins across ${miners.length} miners; rewards for ${res.month}: ${res.created} new, ${res.existing} existing`);
  await disconnectDb();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
