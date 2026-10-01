import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, objectId } from '../../core/validate.js';
import { supervisorSnapshot } from './feed.service.js';

const router = Router();

router.get(
  '/supervisor',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ query: z.object({ zoneId: objectId.optional() }) }),
  asyncHandler(async (req, res) => {
    res.json(await supervisorSnapshot(req.user, req.query.zoneId));
  }),
);

export default { name: 'feed', basePath: '/api/feed', router };
