import cron from 'node-cron';
import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate } from '../../core/validate.js';
import { logger } from '../../core/logger.js';
import { MONTH_RE, listRewards, previousMonth, publishMonth } from './rewards.service.js';

const router = Router();
const month = z.string().regex(MONTH_RE, 'month must be YYYY-MM');

router.get(
  '/',
  authenticate(),
  validate({ query: z.object({ month: month.optional() }) }),
  asyncHandler(async (req, res) => res.json(await listRewards(req.user, req.query.month))),
);

router.post(
  '/publish',
  authenticate(),
  requireRole('admin'),
  validate({ query: z.object({ month }) }),
  asyncHandler(async (req, res) => res.json(await publishMonth(req.query.month, { actor: req.user }))),
);

function init() {
  cron.schedule('30 0 1 * *', () => publishMonth(previousMonth()).catch((err) => logger.error({ err: err.message }, 'monthly rewards failed')), { timezone: 'Asia/Kolkata' });
  logger.info('rewards ready (monthly 00:30 IST on the 1st)');
}

export default { name: 'rewards', basePath: '/api/rewards', router, init };
