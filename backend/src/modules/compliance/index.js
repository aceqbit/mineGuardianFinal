import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, objectId, idParams } from '../../core/validate.js';
import { DECISION_ACTION, ESCALATION_LEVEL } from '../../contracts/enums.js';
import { decide, getReviewByCheckIn, reviewReportUrl } from './compliance.service.js';

const router = Router();

const decisionBody = z.object({
  action: z.enum(DECISION_ACTION),
  escalationLevel: z.enum(ESCALATION_LEVEL).optional(),
  items: z.array(z.object({ key: z.string(), status: z.enum(['PRESENT', 'ABSENT']) }).strict()).min(1),
  note: z.string().max(1000).optional(),
}).strict();

router.get(
  '/reviews/by-checkin/:checkInId',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: z.object({ checkInId: objectId }) }),
  asyncHandler(async (req, res) => res.json(await getReviewByCheckIn(req.user, req.params.checkInId))),
);

router.post(
  '/reviews/:id/decision',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: idParams, body: decisionBody }),
  asyncHandler(async (req, res) => res.json({ review: await decide(req.user, req.params.id, req.body) })),
);

router.get(
  '/reviews/:id/report-url',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: idParams }),
  asyncHandler(async (req, res) => res.json(await reviewReportUrl(req.user, req.params.id))),
);

export default { name: 'compliance', basePath: '/api/compliance', router };
