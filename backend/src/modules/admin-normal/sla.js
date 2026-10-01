// Pure SLA maths (CLAUDE.md §12). `base` is SLA_REMINDER_BASE_MINUTES.

/** Minutes after dueAt at which reminder n (0,1,2) is due: 0, base, 3*base. */
export const reminderOffsetMin = (n, baseMin) => baseMin * (2 ** n - 1);
export const breachOffsetMin = (baseMin) => 7 * baseMin;

/**
 * What the watchdog should do for one review right now.
 * Returns {type:'REMIND', n} | {type:'BREACH'} | null. State lives on the review (sla.remindersSent / sla.breached) so a restart never resends.
 */
export function slaAction(review, now, baseMin) {
  const sla = review?.sla;
  if (review?.status !== 'PENDING_REVIEW' || !sla?.dueAt || sla.breached) return null;
  const due = new Date(sla.dueAt).getTime();
  const t = new Date(now).getTime();
  if (t >= due + breachOffsetMin(baseMin) * 60_000) return { type: 'BREACH' };
  const n = sla.remindersSent ?? 0;
  if (n < 3 && t >= due + reminderOffsetMin(n, baseMin) * 60_000) return { type: 'REMIND', n };
  return null;
}

/** clamp(round(100 * onTime / total - 5 * breaches), 0, 100). No data -> 100. */
export function reliability({ onTime, total, breaches }) {
  if (!total) return 100;
  return Math.max(0, Math.min(100, Math.round((100 * onTime) / total - 5 * breaches)));
}
