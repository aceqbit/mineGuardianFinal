// Pure scoring maths. Formula and constants are from CLAUDE.md §11; nothing here touches the database.

export const WINDOW_DAYS = 30;
export const RECENCY_TAU_DAYS = 15;
export const ON_TIME_MIN = 20;
export const CRITICAL_PPE = ['HELMET', 'SELF_RESCUER', 'CAP_LAMP'];
const HAZARD_POINTS = { LOW: 10, MEDIUM: 25, CRITICAL: 50 };
const HAZARD_UNCLASSIFIED = 10;
const HAZARD_REJECTED = 15;
const DAY_MS = 86_400_000;

export const BADGES = {
  STREAK_7: { label: '7-day streak', xp: 50 },
  STREAK_30: { label: '30-day streak', xp: 150 },
  PERFECT_WEEK: { label: 'Perfect week', xp: 50 },
  HAZARD_HERO: { label: 'Hazard hero', xp: 50 },
  FIRST_PASS_PRO: { label: 'First-pass pro', xp: 50 },
};

const addDays = (day, n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS).toISOString().slice(0, 10);
const isSunday = (day) => new Date(`${day}T00:00:00Z`).getUTCDay() === 0;
const daysBetween = (a, b) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY_MS);

/** Last `n` IST day strings ending at `today`, oldest first. */
export function windowDays(today, n = WINDOW_DAYS) {
  return Array.from({ length: n }, (_, i) => addDays(today, i - (n - 1)));
}

export const recency = (ageDays) => Math.exp(-Math.max(0, ageDays) / RECENCY_TAU_DAYS);

/** Standard competition ranking ("1224") over rows sorted by score, streak, xp desc then name asc. */
export function rankRows(rows) {
  const sorted = [...rows].sort((a, b) => b.score - a.score || b.streak - a.streak || b.xp - a.xp || a.name.localeCompare(b.name));
  let prev = null;
  let rank = 0;
  return sorted.map((r, i) => {
    if (!prev || prev.score !== r.score || prev.streak !== r.streak || prev.xp !== r.xp) rank = i + 1;
    prev = r;
    return { ...r, rank };
  });
}

/**
 * @param {object} p
 * @param {string} p.today IST date string
 * @param {Object<string, {verdict:string, firstPass:boolean, minutesAfterStart:number|null, missing:string[], frozen:boolean, critical:boolean}>} p.days one entry per IST day with a decided review
 * @param {{day:string, kind:'CLOSED'|'REJECTED', severity:string|null}[]} p.hazards hazards closed/rejected in the window (day = IST day of closing)
 * @param {{key:string, earnedAt:Date}[]} [p.priorBadges]
 * @param {Date} [p.now]
 */
export function computeScore({ today, days, hazards = [], priorBadges = [], now = new Date() }) {
  const window = windowDays(today);
  const workdays = window.filter((d) => !isSunday(d));
  let wSum = 0;
  let c = 0;
  let q = 0;
  let qSum = 0;
  let pOn = 0;
  let nonCompliant = 0;
  let nonCompliant7 = 0;
  let critical7 = 0;
  let v = 0;
  let compliantDays = 0;
  let checkins = 0;
  let firstPassCount = 0;

  for (const d of workdays) {
    const e = days[d];
    const age = daysBetween(d, today);
    const r = recency(age);
    if (e?.frozen) continue; // SLA-breached days are excluded from C entirely
    if (!e && d === today) continue; // today is not over yet
    wSum += r;
    if (e) {
      checkins += 1;
      qSum += r;
      if (e.firstPass) { q += r; firstPassCount += 1; }
      if (e.verdict === 'COMPLIANT') {
        c += r;
        compliantDays += 1;
        if (e.minutesAfterStart != null && e.minutesAfterStart <= ON_TIME_MIN) pOn += r;
      } else {
        nonCompliant += 1;
        if (age < 7) nonCompliant7 += 1;
        if (e.critical && age < 7) critical7 += 1;
        v += r * 40 * (e.missing?.some((k) => CRITICAL_PPE.includes(k)) ? 1.5 : 1);
      }
    }
  }
  const C = wSum ? c / wSum : 0;
  const Q = qSum ? q / qSum : 0;
  const P = wSum ? pOn / wSum : 0;

  // Streak S: consecutive compliant workdays ending at the latest workday. Frozen days neither extend nor break it; today without a check-in is ignored.
  let S = 0;
  for (let i = window.length - 1; i >= 0; i -= 1) {
    const d = window[i];
    if (isSunday(d)) continue;
    const e = days[d];
    if (e?.frozen) continue;
    if (!e) { if (d === today) continue; break; }
    if (e.verdict === 'COMPLIANT') S += 1;
    else break;
  }
  const M = 1 + Math.min(S, 30) / 60;

  let H = 0;
  for (const h of hazards) {
    const r = recency(daysBetween(h.day, today));
    H += h.kind === 'REJECTED' ? -r * HAZARD_REJECTED : r * (HAZARD_POINTS[h.severity] ?? HAZARD_UNCLASSIFIED);
  }
  H = Math.max(-60, Math.min(150, H));

  // Badges: award by current state, keep original earnedAt.
  const closed = hazards.filter((h) => h.kind === 'CLOSED').length;
  const last6 = workdays.slice(-6).map((d) => days[d]);
  const earnedNow = [];
  if (S >= 7) earnedNow.push('STREAK_7');
  if (S >= 30) earnedNow.push('STREAK_30');
  if (last6.length === 6 && last6.every((e) => e?.verdict === 'COMPLIANT')) earnedNow.push('PERFECT_WEEK');
  if (closed >= 3) earnedNow.push('HAZARD_HERO');
  if (checkins >= 10 && Q >= 0.9) earnedNow.push('FIRST_PASS_PRO');
  const prior = new Map(priorBadges.map((b) => [b.key, new Date(b.earnedAt)]));
  const badges = earnedNow.map((key) => ({ key, earnedAt: prior.get(key) ?? now }));
  // Earlier badges are kept so they keep counting toward the 90-day bonus.
  for (const [key, earnedAt] of prior) if (!earnedNow.includes(key)) badges.push({ key, earnedAt });
  const B = Math.min(50, 10 * badges.filter((b) => now - new Date(b.earnedAt) <= 90 * DAY_MS).length);

  const raw = M * (500 * C + 120 * Q + 80 * P) + H - v + B;
  const score = Math.max(0, Math.min(1000, Math.round(raw)));

  let riskBand = 'GREEN';
  if (score < 400 || nonCompliant >= 3 || critical7 > 0) riskBand = 'RED';
  else if (score < 700 || nonCompliant7 >= 1) riskBand = 'AMBER';

  const xp = compliantDays * 10 + closed * 15 + badges.reduce((s, b) => s + (BADGES[b.key]?.xp ?? 0), 0);

  return {
    score,
    streak: S,
    xp,
    badges,
    riskBand,
    components: { C: +C.toFixed(4), Q: +Q.toFixed(4), P: +P.toFixed(4), H: +H.toFixed(2), V: +v.toFixed(2), B, M: +M.toFixed(4) },
  };
}
