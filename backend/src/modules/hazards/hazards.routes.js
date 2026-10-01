import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, idParams, objectId } from '../../core/validate.js';
import { HAZARD_CATEGORY, HAZARD_STATUS } from '../../contracts/enums.js';
import { MAX_UPLOAD_BYTES } from '../checkins/config.js';
import { createHazard, listHazards, updateHazard } from './hazards.service.js';

export const router = Router();

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_UPLOAD_BYTES, files: 1 } });
const optNum = z.preprocess((v) => (v === '' || v === undefined || v === null ? undefined : Number(v)), z.number().finite().optional());
const optIso = z.preprocess((v) => (v === '' || v === undefined ? undefined : v), z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid ISO date').optional());

const createBody = z.object({
  clientId: z.string().uuid(),
  category: z.enum(HAZARD_CATEGORY),
  capturedAt: optIso,
  queuedAt: optIso,
  uploadStartedAt: optIso,
  lat: optNum.refine((v) => v === undefined || (v >= -90 && v <= 90), 'lat out of range'),
  lng: optNum.refine((v) => v === undefined || (v >= -180 && v <= 180), 'lng out of range'),
  accuracyM: optNum,
  sha256: z.string().regex(/^[a-fA-F0-9]{64}$/),
  source: z.enum(['camera', 'gallery']).default('camera'),
});

router.post(
  '/',
  authenticate(),
  requireRole('miner', 'supervisor'),
  upload.single('image'),
  validate({ body: createBody }),
  asyncHandler(async (req, res) => {
    const { hazard, created } = await createHazard({ user: req.user, file: req.file, body: req.body });
    res.status(created ? 201 : 200).json({ hazard });
  }),
);

router.get(
  '/',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({
    query: z.object({
      zoneId: objectId.optional(),
      status: z.enum(HAZARD_STATUS).optional(),
      limit: z.coerce.number().int().min(1).max(200).default(50),
    }),
  }),
  asyncHandler(async (req, res) => {
    res.json(await listHazards({ user: req.user, ...req.query }));
  }),
);

router.patch(
  '/:id',
  authenticate(),
  requireRole('supervisor', 'admin'),
  validate({ params: idParams, body: z.object({ status: z.string(), note: z.string().max(500).optional() }).strict() }),
  asyncHandler(async (req, res) => {
    res.json({ hazard: await updateHazard({ user: req.user, id: req.params.id, status: req.body.status, note: req.body.note }) });
  }),
);
