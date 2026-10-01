import { SHIFT_HOURS } from '../../contracts/enums.js';
import { STALE_AFTER_MS, OFFLINE_DELAYED_MS, CLOCK_SKEW_MAX_SEC, LOW_ACCURACY_M, SHIFT_TOLERANCE_MIN } from './config.js';

const IST_MS = 5.5 * 60 * 60 * 1000;

/** Wall-clock IST minutes since midnight for a UTC instant. */
export function istMinutes(date) {
  const d = new Date(new Date(date).getTime() + IST_MS);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}

/** yyyy-mm-dd in IST. */
export function istDateString(date) {
  return new Date(new Date(date).getTime() + IST_MS).toISOString().slice(0, 10);
}

const toMin = (hhmm) => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

/** Within the shift window +/- tolerance minutes (IST). Shift C wraps midnight. */
export function withinShiftWindow(shift, date, windows = null, toleranceMin = SHIFT_TOLERANCE_MIN) {
  const w = windows?.find((x) => x.shift === shift);
  const [startS, endS] = w ? [w.start, w.end] : SHIFT_HOURS[shift] || [];
  if (!startS) return true;
  const start = toMin(startS) - toleranceMin;
  const end = toMin(endS) + toleranceMin;
  const now = istMinutes(date);
  if (toMin(endS) <= toMin(startS)) {
    // wraps midnight
    const s = (start + 1440) % 1440;
    const e = (end + 1440) % 1440;
    return now >= s || now < e;
  }
  return now >= start && now < end;
}

/**
 * Pure integrity-flag computation. All dates are Date or null.
 * Returns { flags, clockSkewSec }.
 */
export function computeIntegrityFlags({ source, exifTakenAt, capturedAt, queuedAt, uploadStartedAt, receivedAt, accuracyM, hasLocation, insideZone, withinShift }) {
  const flags = [];
  if (source === 'gallery') {
    flags.push('GALLERY_SOURCE');
    if (!exifTakenAt) flags.push('NO_EXIF');
  }
  const sent = queuedAt || uploadStartedAt;
  if (capturedAt && sent && sent.getTime() - capturedAt.getTime() > STALE_AFTER_MS) flags.push('STALE_PHOTO');
  if (queuedAt && receivedAt.getTime() - queuedAt.getTime() > OFFLINE_DELAYED_MS) flags.push('OFFLINE_DELAYED');
  let clockSkewSec = 0;
  if (uploadStartedAt) {
    clockSkewSec = Math.round((uploadStartedAt.getTime() - receivedAt.getTime()) / 1000);
    if (Math.abs(clockSkewSec) > CLOCK_SKEW_MAX_SEC) flags.push('CLOCK_SKEW');
  }
  if (!hasLocation || accuracyM == null || accuracyM > LOW_ACCURACY_M) flags.push('LOW_GPS_ACCURACY');
  if (hasLocation && insideZone === false) flags.push('OUTSIDE_ZONE');
  if (withinShift === false) flags.push('OUT_OF_SHIFT');
  return { flags, clockSkewSec };
}
