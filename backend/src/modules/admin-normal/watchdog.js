import { env } from '../../config/env.js';
import { audit } from '../../core/audit.js';
import { sendToUsers } from '../../core/fcm.js';
import { logger } from '../../core/logger.js';
import { emitTo } from '../../core/socket.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { User } from '../../models/User.js';
import { recomputeWorker } from '../scoring/scoring.service.js';
import { slaAction } from './sla.js';

/** One watchdog pass. Idempotent: a conditional update claims each step, so two ticks (or a restart) never repeat it. */
export async function watchdogTick(now = new Date()) {
  const pending = await ComplianceReview.find({ status: 'PENDING_REVIEW', 'sla.breached': { $ne: true }, 'sla.dueAt': { $lte: now } });
  const done = { reminders: 0, breaches: 0 };
  for (const review of pending) {
    const action = slaAction(review, now, env.slaReminderBaseMinutes);
    if (!action) continue;
    try {
      if (action.type === 'REMIND') {
        const claimed = await ComplianceReview.updateOne({ _id: review._id, 'sla.remindersSent': action.n }, { $set: { 'sla.remindersSent': action.n + 1, 'sla.lastReminderAt': now } });
        if (!claimed.modifiedCount) continue;
        const sups = await User.find({ role: 'supervisor', zoneId: review.zoneId, status: 'active' });
        await sendToUsers(sups.map((s) => String(s._id)), { title: 'Review overdue', body: `A compliance check-in is waiting for your decision (reminder ${action.n + 1} of 3).`, data: { type: 'sla_reminder', reviewId: String(review._id), checkInId: String(review.checkInId) } });
        if (action.n === 2) {
          const admins = await User.find({ role: 'admin', status: 'active' });
          await sendToUsers(admins.map((a) => String(a._id)), { title: 'Review escalation', body: 'A check-in review is close to breaching its SLA.', data: { type: 'sla_escalation', reviewId: String(review._id) } });
        }
        done.reminders += 1;
      } else {
        const claimed = await ComplianceReview.updateOne({ _id: review._id, 'sla.breached': { $ne: true }, status: 'PENDING_REVIEW' }, { $set: { 'sla.breached': true, 'sla.breachedAt': now, 'sla.streakFrozen': true } });
        if (!claimed.modifiedCount) continue;
        emitTo(['role:admin'], 'sla:breach', { reviewId: String(review._id), checkInId: String(review.checkInId), zoneId: String(review.zoneId), workerId: String(review.workerId), breachedAt: now.toISOString() });
        const admins = await User.find({ role: 'admin', status: 'active' });
        await sendToUsers(admins.map((a) => String(a._id)), { title: 'SLA breached', body: 'A compliance review missed its deadline. The worker streak is frozen.', data: { type: 'sla_breach', reviewId: String(review._id) } });
        await audit(null, 'SLA_BREACH', 'compliance_review', review._id, { zoneId: String(review.zoneId) });
        await recomputeWorker(review.workerId).catch(() => null);
        done.breaches += 1;
      }
    } catch (err) {
      logger.error({ err: err.message, reviewId: String(review._id) }, 'sla watchdog step failed');
    }
  }
  return done;
}
