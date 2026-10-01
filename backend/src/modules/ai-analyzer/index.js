import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole, isZoneStaff } from '../../core/auth.js';
import { AppError, asyncHandler } from '../../core/errors.js';
import { validate, objectId } from '../../core/validate.js';
import { logger } from '../../core/logger.js';
import { subscribe } from '../../core/bus.js';
import { CheckIn } from '../../models/CheckIn.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { aiConfig } from './config.js';
import { createQueue } from './jobs.js';
import { findStuckWork, processCheckIn, processHazard } from './pipeline.js';

const queue = createQueue({ concurrency: 3, retries: 2, delaysMs: [2000, 6000] });
const router = Router();

router.post(
  '/analyze/checkin/:checkInId',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: z.object({ checkInId: objectId }) }),
  asyncHandler(async (req, res) => {
    const ci = await CheckIn.findById(req.params.checkInId);
    if (!ci) throw new AppError(404, 'NOT_FOUND', 'Check-in not found');
    if (!isZoneStaff(req.user, ci.zoneId)) throw new AppError(403, 'FORBIDDEN_ROLE', 'Not your zone');
    const review = await ComplianceReview.findOne({ checkInId: ci._id });
    if (review?.status === 'DECIDED') throw new AppError(409, 'ALREADY_DECIDED', 'This review is already decided');
    const queued = queue.enqueue(`rerun:${ci._id}`, () => processCheckIn(String(ci._id), { force: true }));
    res.status(202).json({ ok: true, queued });
  }),
);

router.get(
  '/health',
  authenticate(),
  requireRole('admin'),
  asyncHandler(async (_req, res) => {
    const c = aiConfig();
    res.json({ mlMode: c.mlMode, model: c.model, yoloProvider: c.yoloProvider, queueDepth: queue.depth, lastLatencyMs: queue.stats.lastLatencyMs });
  }),
);

async function init() {
  subscribe('CheckInCreated', ({ data }) => {
    queue.enqueue(`checkin:${data.checkInId}`, () => processCheckIn(data.checkInId));
  });
  subscribe('HazardCreated', ({ data }) => {
    queue.enqueue(`hazard:${data.hazardId}`, () => processHazard(data.hazardId));
  });
  try {
    const stuck = await findStuckWork();
    for (const id of stuck.checkIns) queue.enqueue(`checkin:${id}`, () => processCheckIn(id, { force: true }));
    for (const id of stuck.hazards) queue.enqueue(`hazard:${id}`, () => processHazard(id));
    if (stuck.checkIns.length || stuck.hazards.length) logger.info(`AI recovery: re-enqueued ${stuck.checkIns.length} check-ins, ${stuck.hazards.length} hazards`);
  } catch (err) {
    logger.warn({ err: err.message }, 'AI recovery scan failed');
  }
  const c = aiConfig();
  logger.info(`ai-analyzer ready (mode=${c.mlMode}, model=${c.model}, yolo=${c.yoloProvider})`);
}

export default { name: 'ai-analyzer', basePath: '/api/ai', router, init };
