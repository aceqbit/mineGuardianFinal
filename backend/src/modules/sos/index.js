import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate } from '../../core/validate.js';
import { cancelSos, createSos } from './sos.service.js';

const router = Router();

const optNum = z.number().finite().optional().nullable();
const createBody = z.object({
  clientId: z.string().uuid(),
  lat: optNum.refine((v) => v == null || (v >= -90 && v <= 90), 'lat out of range'),
  lng: optNum.refine((v) => v == null || (v >= -180 && v <= 180), 'lng out of range'),
  accuracyM: optNum.refine((v) => v == null || v >= 0, 'accuracyM must be >= 0'),
  triggeredAt: z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid ISO date'),
}).strict();

router.post(
  '/',
  authenticate(),
  requireRole('miner', 'supervisor'),
  validate({ body: createBody }),
  asyncHandler(async (req, res) => {
    const { sos, created } = await createSos({ user: req.user, body: req.body });
    res.status(created ? 201 : 200).json({ sos });
  }),
);

router.post(
  '/:id/cancel',
  authenticate(),
  requireRole('miner', 'supervisor'),
  validate({ params: z.object({ id: z.string().min(8).max(64) }) }),
  asyncHandler(async (req, res) => {
    res.json({ sos: await cancelSos({ user: req.user, key: req.params.id }) });
  }),
);

export default { name: 'sos', basePath: '/api/sos', router };
