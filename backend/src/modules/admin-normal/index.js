import cron from 'node-cron';
import { Router } from 'express';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, objectId } from '../../core/validate.js';
import { logger } from '../../core/logger.js';
import { istDateString } from '../checkins/integrity.js';
import { ackEscalation, compensate, generateReport, hazardAudit, listReports, reportUrl, slaOverview } from './admin-normal.service.js';
import { watchdogTick } from './watchdog.js';

const router = Router();
const admin = [authenticate(), requireRole('admin')];
const idParams = z.object({ reviewId: objectId });

router.get('/sla', ...admin, asyncHandler(async (_req, res) => res.json(await slaOverview())));
router.get('/hazard-audit', ...admin, validate({ query: z.object({ days: z.coerce.number().int().min(1).max(90).optional() }) }), asyncHandler(async (req, res) => res.json(await hazardAudit({ days: req.query.days }))));
router.get('/reports', ...admin, asyncHandler(async (_req, res) => res.json(await listReports())));
router.get('/reports/:id/url', ...admin, validate({ params: z.object({ id: objectId }) }), asyncHandler(async (req, res) => res.json(await reportUrl(req.params.id))));
router.post(
  '/reports/generate',
  ...admin,
  validate({ body: z.object({ day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional() }).strict() }),
  asyncHandler(async (req, res) => res.status(201).json(await generateReport(req.user, req.body.day))),
);
router.post(
  '/compensation/:reviewId',
  ...admin,
  validate({ params: idParams, body: z.object({ approve: z.boolean(), note: z.string().trim().min(5).max(500) }).strict() }),
  asyncHandler(async (req, res) => res.json(await compensate(req.user, req.params.reviewId, req.body))),
);
router.post('/escalations/:reviewId/ack', ...admin, validate({ params: idParams }), asyncHandler(async (req, res) => res.json(await ackEscalation(req.user, req.params.reviewId))));

function init() {
  const every = env.DEMO_FAST_MODE ? '*/10 * * * * *' : '* * * * *';
  cron.schedule(every, () => watchdogTick().catch((err) => logger.error({ err: err.message }, 'sla watchdog failed')));
  cron.schedule('55 23 * * *', () => generateReport(null, istDateString(new Date()), { auto: true }).catch((err) => logger.error({ err: err.message }, 'daily report failed')), { timezone: 'Asia/Kolkata' });
  logger.info(`admin-normal ready (SLA watchdog ${env.DEMO_FAST_MODE ? 'every 10 s' : 'every minute'})`);
}

export default { name: 'admin-normal', basePath: '/api/admin', router, init };
