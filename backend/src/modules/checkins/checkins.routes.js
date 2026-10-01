import { Router } from 'express';
import multer from 'multer';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { authenticate, requireRole, isZoneStaff } from '../../core/auth.js';
import { AppError, asyncHandler } from '../../core/errors.js';
import { validate, idParams } from '../../core/validate.js';
import { CheckIn } from '../../models/CheckIn.js';
import { MAX_UPLOAD_BYTES, UPLOADS_PER_MINUTE } from './config.js';
import { checkInView, createCheckIn, listMine, reviewSummaries, summarizeReview } from './checkins.service.js';

export const router = Router();

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_UPLOAD_BYTES, files: 1 } });
const perUser = rateLimit({ windowMs: 60_000, limit: UPLOADS_PER_MINUTE, keyGenerator: (req) => String(req.user?._id ?? req.ip), standardHeaders: true, legacyHeaders: false, validate: false });

const optNum = z.preprocess((v) => (v === '' || v === undefined || v === null ? undefined : Number(v)), z.number().finite().optional());
const optIso = z.preprocess((v) => (v === '' || v === undefined ? undefined : v), z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid ISO date').optional());
const clientQuality = z.preprocess((v) => {
  if (typeof v !== 'string') return v ?? {};
  try {
    return JSON.parse(v);
  } catch {
    return {};
  }
}, z.object({ blurScore: z.number().optional(), brightness: z.number().optional(), width: z.number().optional(), height: z.number().optional(), poseChecked: z.boolean().optional(), poseOk: z.boolean().optional(), missingLandmarks: z.array(z.string()).optional() }).passthrough());

const createBody = z.object({
  clientId: z.string().uuid(),
  capturedAt: optIso,
  exifTakenAt: optIso,
  queuedAt: optIso,
  uploadStartedAt: z.string().refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid ISO date'),
  source: z.enum(['camera', 'gallery']),
  attempt: z.coerce.number().int().min(1),
  lat: optNum,
  lng: optNum,
  accuracyM: optNum,
  sha256: z.string().regex(/^[a-fA-F0-9]{64}$/),
  clientQuality,
});

router.post(
  '/',
  authenticate(),
  requireRole('miner'),
  perUser,
  upload.single('image'),
  validate({ body: createBody }),
  asyncHandler(async (req, res) => {
    const { checkIn, created } = await createCheckIn({ user: req.user, file: req.file, body: req.body });
    res.status(created ? 201 : 200).json({ checkIn });
  }),
);

router.get(
  '/mine',
  authenticate(),
  requireRole('miner'),
  validate({ query: z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) }) }),
  asyncHandler(async (req, res) => {
    res.json(await listMine(req.user, req.query.limit));
  }),
);

router.get(
  '/:id',
  authenticate(),
  validate({ params: idParams }),
  asyncHandler(async (req, res) => {
    const ci = await CheckIn.findById(req.params.id);
    if (!ci) throw new AppError(404, 'NOT_FOUND', 'Check-in not found');
    const owner = String(ci.workerId) === String(req.user._id);
    if (!owner && !isZoneStaff(req.user, ci.zoneId)) throw new AppError(403, 'FORBIDDEN_ROLE', 'Not allowed');
    const out = await checkInView(ci);
    out.review = summarizeReview((await reviewSummaries([ci._id])).get(String(ci._id)));
    res.json(out);
  }),
);
