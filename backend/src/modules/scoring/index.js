import cron from 'node-cron';
import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, objectId } from '../../core/validate.js';
import { logger } from '../../core/logger.js';
import { subscribe } from '../../core/bus.js';
import { Hazard } from '../../models/Hazard.js';
import { leaderboard, myStanding, recomputeAll, recomputeWorker, supervisorBoard, zoneScores } from './scoring.service.js';

const router = Router();

router.get(
  '/leaderboard',
  authenticate(),
  validate({ query: z.object({ period: z.enum(['month', 'all']).optional(), zoneId: objectId.optional() }) }),
  asyncHandler(async (req, res) => res.json(await leaderboard({ zoneId: req.query.zoneId }))),
);
router.get('/leaderboard/me', authenticate(), requireRole('miner'), asyncHandler(async (req, res) => res.json(await myStanding(req.user))));
router.get('/leaderboard/supervisors', authenticate(), requireRole('supervisor', 'admin'), asyncHandler(async (_req, res) => res.json(await supervisorBoard())));
router.get(
  '/scores/zone/:zoneId',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: z.object({ zoneId: objectId }) }),
  asyncHandler(async (req, res) => res.json(await zoneScores(req.user, req.params.zoneId))),
);

function init() {
  subscribe('ComplianceReviewed', async ({ data }) => {
    await recomputeWorker(data.workerId);
  });
  subscribe('HazardStatusChanged', async ({ data }) => {
    if (!['CLOSED', 'REJECTED'].includes(data.status)) return;
    const h = await Hazard.findById(data.hazardId);
    if (h) await recomputeWorker(h.reporterId);
  });
  cron.schedule('10 0 * * *', () => recomputeAll().catch((err) => logger.error({ err: err.message }, 'nightly scoring failed')), { timezone: 'Asia/Kolkata' });
  logger.info('scoring ready (nightly 00:10 IST)');
}

export default { name: 'scoring', basePath: '/api', router, init };
