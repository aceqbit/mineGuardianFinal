import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { signedUrl, uploadBuffer } from '../../core/storage.js';
import { CheckIn } from '../../models/CheckIn.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { Hazard } from '../../models/Hazard.js';
import { Report } from '../../models/Report.js';
import { SosEvent } from '../../models/SosEvent.js';
import { User } from '../../models/User.js';
import { Zone } from '../../models/Zone.js';
import { istDateString } from '../checkins/integrity.js';
import { recomputeWorker } from '../scoring/scoring.service.js';
import { buildDailyReportPdf } from './report.pdf.js';
import { reliability } from './sla.js';

const DAY_MS = 86_400_000;
const dayRange = (day) => [new Date(`${day}T00:00:00+05:30`), new Date(new Date(`${day}T00:00:00+05:30`).getTime() + DAY_MS)];

/** Supervisor reliability over the last 30 days plus the live list of breaches and unacknowledged escalations. */
export async function slaOverview(now = new Date()) {
  const since = new Date(now.getTime() - 30 * DAY_MS);
  const [sups, zones, reviews] = await Promise.all([
    User.find({ role: 'supervisor', status: 'active' }),
    Zone.find(),
    ComplianceReview.find({ $or: [{ 'decision.decidedAt': { $gte: since } }, { 'sla.breachedAt': { $gte: since } }, { status: 'PENDING_REVIEW' }] }),
  ]);
  const zoneName = new Map(zones.map((z) => [String(z._id), z.code]));
  const supervisors = sups.map((s) => {
    const decided = reviews.filter((r) => r.status === 'DECIDED' && String(r.decision?.decidedBy) === String(s._id) && new Date(r.decision.decidedAt) >= since);
    const onTime = decided.filter((r) => r.sla?.dueAt && new Date(r.decision.decidedAt) <= new Date(r.sla.dueAt)).length;
    const breaches = reviews.filter((r) => String(r.zoneId) === String(s.zoneId) && r.sla?.breached && !r.sla?.compensated && new Date(r.sla.breachedAt ?? 0) >= since).length;
    const total = decided.length + breaches;
    return {
      id: String(s._id), fullName: s.fullName, zoneId: String(s.zoneId), zoneCode: zoneName.get(String(s.zoneId)) ?? '',
      decided: decided.length, onTime, breaches, noData: total === 0, reliability: reliability({ onTime, total, breaches }),
    };
  });
  const workers = new Map((await User.find({ _id: { $in: reviews.map((r) => r.workerId) } })).map((u) => [String(u._id), u.fullName]));
  const item = (r) => ({ reviewId: String(r._id), checkInId: String(r.checkInId), zoneCode: zoneName.get(String(r.zoneId)) ?? '', workerName: workers.get(String(r.workerId)) ?? '', dueAt: r.sla?.dueAt, remindersSent: r.sla?.remindersSent ?? 0, breached: !!r.sla?.breached, breachedAt: r.sla?.breachedAt, compensated: !!r.sla?.compensated, escalationAcked: !!r.sla?.escalationAcked });
  return {
    supervisors,
    breaches: reviews.filter((r) => r.sla?.breached).sort((a, b) => new Date(b.sla.breachedAt) - new Date(a.sla.breachedAt)).map(item),
    escalations: reviews.filter((r) => r.status === 'PENDING_REVIEW' && (r.sla?.remindersSent ?? 0) >= 3 && !r.sla?.breached && !r.sla?.escalationAcked).map(item),
    pending: reviews.filter((r) => r.status === 'PENDING_REVIEW').length,
  };
}

export async function compensate(admin, reviewId, { approve, note }) {
  const review = await ComplianceReview.findById(reviewId);
  if (!review) throw new AppError(404, 'NOT_FOUND', 'Review not found');
  if (!review.sla?.breached) throw new AppError(409, 'NOT_BREACHED', 'Only a breached review can be compensated');
  if (approve) {
    review.sla.compensated = true;
    review.sla.compensatedBy = admin._id;
    review.markModified('sla');
    await review.save();
    await recomputeWorker(review.workerId).catch(() => null);
  }
  await audit(admin, approve ? 'SLA_COMPENSATED' : 'SLA_COMPENSATION_DENIED', 'compliance_review', review._id, { note });
  return { reviewId: String(review._id), compensated: !!review.sla.compensated };
}

export async function ackEscalation(admin, reviewId) {
  const res = await ComplianceReview.updateOne({ _id: reviewId }, { $set: { 'sla.escalationAcked': true } });
  if (!res.matchedCount) throw new AppError(404, 'NOT_FOUND', 'Review not found');
  await audit(admin, 'ESCALATION_ACKED', 'compliance_review', reviewId);
  return { reviewId: String(reviewId), escalationAcked: true };
}

const mins = (a, b) => (a && b ? Math.max(0, Math.round((new Date(b) - new Date(a)) / 60000)) : null);

/** Per-hazard response timeline for the last `days` days and simple aggregates. */
export async function hazardAudit({ days = 7, now = new Date() } = {}) {
  const since = new Date(now.getTime() - days * DAY_MS);
  const hazards = await Hazard.find({ createdAt: { $gte: since } }).sort({ createdAt: -1 });
  const [users, zones] = await Promise.all([User.find({ _id: { $in: hazards.flatMap((h) => [h.reporterId, h.acknowledgedBy, h.closedBy].filter(Boolean)) } }), Zone.find()]);
  const name = new Map(users.map((u) => [String(u._id), u.fullName]));
  const code = new Map(zones.map((z) => [String(z._id), z.code]));
  const rows = hazards.map((h) => ({
    id: String(h._id), category: h.category, severity: h.ai?.severity ?? null, status: h.status, zoneCode: code.get(String(h.zoneId)) ?? '',
    reporter: name.get(String(h.reporterId)) ?? '', createdAt: h.createdAt, acknowledgedBy: name.get(String(h.acknowledgedBy)) ?? null, closedBy: name.get(String(h.closedBy)) ?? null,
    ackMinutes: mins(h.createdAt, h.acknowledgedAt), closeMinutes: mins(h.createdAt, h.closedAt), closeNote: h.closeNote ?? null,
    slow: h.status === 'OPEN' && mins(h.createdAt, now) > 30,
  }));
  const acks = rows.map((r) => r.ackMinutes).filter((x) => x != null).sort((a, b) => a - b);
  return {
    days,
    total: rows.length,
    byStatus: Object.fromEntries(['OPEN', 'ACKNOWLEDGED', 'CLOSED', 'REJECTED'].map((s) => [s, rows.filter((r) => r.status === s).length])),
    medianAckMinutes: acks.length ? acks[Math.floor(acks.length / 2)] : null,
    slowOpen: rows.filter((r) => r.slow).length,
    hazards: rows,
  };
}

/** Facts for one IST day. */
export async function dailySummary(day) {
  const [from, to] = dayRange(day);
  const [checkIns, reviews, hazards, sos, breaches, zones] = await Promise.all([
    CheckIn.find({ createdAt: { $gte: from, $lt: to } }),
    ComplianceReview.find({ 'decision.decidedAt': { $gte: from, $lt: to } }),
    Hazard.find({ createdAt: { $gte: from, $lt: to } }),
    SosEvent.countDocuments({ createdAt: { $gte: from, $lt: to } }),
    ComplianceReview.countDocuments({ 'sla.breachedAt': { $gte: from, $lt: to } }),
    Zone.find().sort({ code: 1 }),
  ]);
  const missing = {};
  for (const r of reviews) for (const i of r.decision?.items ?? []) if (i.status === 'ABSENT') missing[i.key] = (missing[i.key] ?? 0) + 1;
  const compliant = reviews.filter((r) => r.decision?.finalVerdict === 'COMPLIANT').length;
  return {
    day,
    checkIns: checkIns.length,
    reviewed: reviews.length,
    compliant,
    nonCompliant: reviews.length - compliant,
    compliancePct: reviews.length ? Math.round((100 * compliant) / reviews.length) : null,
    overrides: reviews.filter((r) => r.decision?.action === 'OVERRIDE').length,
    escalations: reviews.filter((r) => r.decision?.action === 'ESCALATE').length,
    hazards: { opened: hazards.length, closed: hazards.filter((h) => h.status === 'CLOSED').length, critical: hazards.filter((h) => h.ai?.severity === 'CRITICAL').length },
    sosEvents: sos,
    slaBreaches: breaches,
    missingPpe: Object.entries(missing).sort((a, b) => b[1] - a[1]).map(([key, count]) => ({ key, count })),
    zones: zones.map((z) => {
      const rs = reviews.filter((r) => String(r.zoneId) === String(z._id));
      const ok = rs.filter((r) => r.decision?.finalVerdict === 'COMPLIANT').length;
      return { code: z.code, name: z.name, reviewed: rs.length, compliant: ok, compliancePct: rs.length ? Math.round((100 * ok) / rs.length) : null };
    }),
  };
}

export async function generateReport(admin, day = istDateString(new Date()), { auto = false } = {}) {
  const summary = await dailySummary(day);
  const report = await Report.findOneAndUpdate({ type: 'DAILY', day }, { $set: { summary, generatedBy: admin?._id, auto } }, { upsert: true, new: true, setDefaultsOnInsert: true });
  const pdf = await buildDailyReportPdf(summary);
  const path = `reports/${report._id}.pdf`;
  await uploadBuffer(path, pdf, 'application/pdf');
  report.storagePath = path;
  await report.save();
  await audit(admin, 'REPORT_GENERATED', 'report', report._id, { day, auto });
  return report.toJSON();
}

export async function listReports(limit = 30) {
  return (await Report.find().sort({ day: -1 }).limit(limit)).map((r) => r.toJSON());
}

/** 7-day signed link. */
export async function reportUrl(id) {
  const r = await Report.findById(id);
  if (!r?.storagePath) throw new AppError(404, 'NOT_FOUND', 'Report not found');
  return { url: await signedUrl(r.storagePath, 7 * 24 * 60) };
}
