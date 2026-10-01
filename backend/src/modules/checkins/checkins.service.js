import crypto from 'node:crypto';
import mongoose from 'mongoose';
import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { bus } from '../../core/bus.js';
import { emitTo } from '../../core/socket.js';
import { env } from '../../config/env.js';
import { uploadBuffer, signedUrl } from '../../core/storage.js';
import { pointInPolygon, toPoint } from '../../core/geo.js';
import { CheckIn } from '../../models/CheckIn.js';
import { Zone } from '../../models/Zone.js';
import { analyzeQuality, sniffImageType } from './image-quality.js';
import { computeIntegrityFlags, istDateString, withinShiftWindow } from './integrity.js';

const toDate = (v) => (v ? new Date(v) : null);

export async function checkInView(ci) {
  const o = ci.toJSON();
  o.imageUrl = await signedUrl(ci.storagePath).catch(() => null);
  return o;
}

export async function createCheckIn({ user, file, body }) {
  // 1. idempotency
  const existing = await CheckIn.findOne({ workerId: user._id, clientId: body.clientId });
  if (existing) return { checkIn: await checkInView(existing), created: false };

  if (!file) throw new AppError(400, 'VALIDATION_ERROR', 'image file is required', [{ path: 'image', message: 'Required' }]);
  const buf = file.buffer;
  // 2. magic bytes
  if (!sniffImageType(buf)) throw new AppError(400, 'UNSUPPORTED_IMAGE', 'Only JPEG or PNG photos are accepted');
  // 3. hash
  const sha = crypto.createHash('sha256').update(buf).digest('hex');
  if (sha !== body.sha256.toLowerCase()) throw new AppError(400, 'HASH_MISMATCH', 'Upload was corrupted. Please retry');
  if (await CheckIn.exists({ workerId: user._id, sha256: sha })) {
    throw new AppError(409, 'DUPLICATE_PHOTO', 'This exact photo was already submitted');
  }
  // 4. server quality
  let serverQuality;
  try {
    serverQuality = await analyzeQuality(buf);
  } catch {
    throw new AppError(400, 'UNSUPPORTED_IMAGE', 'This photo could not be read');
  }
  if (!serverQuality.pass) {
    throw new AppError(422, 'QUALITY_REJECTED', 'Photo quality is too low. Please retake', { reasons: serverQuality.reasons });
  }

  // 5. integrity flags
  const zone = await Zone.findById(user.zoneId);
  if (!zone) throw new AppError(400, 'ZONE_NOT_FOUND', 'Your zone was not found');
  const receivedAt = new Date();
  const capturedAt = toDate(body.capturedAt);
  const exifTakenAt = toDate(body.exifTakenAt);
  const queuedAt = toDate(body.queuedAt);
  const uploadStartedAt = toDate(body.uploadStartedAt);
  const hasLocation = Number.isFinite(body.lat) && Number.isFinite(body.lng);
  const insideZone = hasLocation ? pointInPolygon({ lat: body.lat, lng: body.lng }, zone.polygon) : null;
  const withinShift = withinShiftWindow(user.shift, capturedAt || receivedAt, zone.shiftWindows);
  const { flags, clockSkewSec } = computeIntegrityFlags({
    source: body.source, exifTakenAt, capturedAt, queuedAt, uploadStartedAt, receivedAt,
    accuracyM: body.accuracyM, hasLocation, insideZone, withinShift,
  });
  if (env.GEOFENCE_ENFORCE && hasLocation && insideZone === false) {
    throw new AppError(422, 'OUTSIDE_ZONE', 'You must be inside your zone to check in');
  }
  if (env.SHIFT_WINDOW_ENFORCE && !withinShift) {
    throw new AppError(422, 'OUT_OF_SHIFT', 'You can only check in during your shift');
  }

  // 6. storage (id first)
  const id = new mongoose.Types.ObjectId();
  const storagePath = `checkins/${user._id}/${istDateString(receivedAt)}/${id}.jpg`;
  await uploadBuffer(storagePath, buf, sniffImageType(buf) === 'png' ? 'image/png' : 'image/jpeg');

  // 7. create
  const checkIn = await CheckIn.create({
    _id: id,
    workerId: user._id,
    zoneId: zone._id,
    shift: user.shift,
    clientId: body.clientId,
    storagePath,
    source: body.source,
    attempt: body.attempt,
    capturedAt, exifTakenAt, queuedAt, uploadStartedAt, receivedAt, clockSkewSec,
    location: hasLocation ? toPoint(body.lat, body.lng) : undefined,
    accuracyM: body.accuracyM ?? undefined,
    insideZone: insideZone ?? undefined,
    withinShift,
    clientQuality: body.clientQuality,
    serverQuality: { blurScore: serverQuality.blurScore, brightness: serverQuality.brightness, width: serverQuality.width, height: serverQuality.height, pass: true },
    sha256: sha,
    integrityFlags: flags,
    status: 'RECEIVED',
  });

  // 8. audit + bus + socket
  await audit(user, 'CHECKIN_CREATED', 'check_in', checkIn._id, { flags, attempt: body.attempt });
  bus.publish('CheckInCreated', { checkInId: String(checkIn._id) });
  const thumbUrl = await signedUrl(storagePath).catch(() => null);
  emitTo([`zone:${zone._id}:supervisors`, 'role:admin'], 'checkin:new', {
    checkInId: String(checkIn._id), workerId: String(user._id), workerName: user.fullName, zoneId: String(zone._id),
    capturedAt: (capturedAt || receivedAt).toISOString(), status: checkIn.status, integrityFlags: flags, thumbUrl,
  });

  return { checkIn: await checkInView(checkIn), created: true };
}

/** Review summary read from the raw collection (Phase 1 imports no Phase 2 models). */
export async function reviewSummaries(checkInIds) {
  try {
    const col = mongoose.connection.collection('compliance_reviews');
    const rows = await col.find({ checkInId: { $in: checkInIds } }).toArray();
    return new Map(rows.map((r) => [String(r.checkInId), r]));
  } catch {
    return new Map();
  }
}

export function summarizeReview(r) {
  if (!r) return undefined;
  const missing = (r.decision?.items ?? []).filter((i) => i.status === 'ABSENT').map((i) => i.key);
  return {
    reviewId: String(r._id),
    status: r.status,
    verdict: r.ai?.overallVerdict,
    overallConfidence: r.ai?.overallConfidence,
    finalVerdict: r.decision?.finalVerdict,
    decisionAction: r.decision?.action,
    missing,
  };
}

export async function listMine(user, limit) {
  const items = await CheckIn.find({ workerId: user._id }).sort({ createdAt: -1 }).limit(limit);
  const reviews = await reviewSummaries(items.map((i) => i._id));
  return Promise.all(
    items.map(async (ci) => {
      const o = await checkInView(ci);
      o.review = summarizeReview(reviews.get(String(ci._id)));
      return o;
    }),
  );
}
