// NON-NEGOTIABLE SAFETY (CLAUDE.md §13): Twilio must never be pointed at a real emergency number.
import { parsePhoneNumberFromString } from 'libphonenumber-js/max';
import { AppError } from '../../core/errors.js';

/** National numbers that real emergency services answer on. Refused as dial targets. */
export const EMERGENCY_BLOCKLIST = Object.freeze(['112', '100', '101', '102', '108', '1070', '1077', '1078', '911', '999']);
export const MIN_DIAL_DIGITS = 8;
export const VOICE_MAX = 450;
export const SMS_MAX = 320;

const unsafe = (message) => new AppError(400, 'UNSAFE_DIAL_TARGET', message, [{ path: 'dialE164', message }]);

/** Throws 400 UNSAFE_DIAL_TARGET unless `dialE164` is a valid, full-length number that is not on the blocklist. */
export function assertSafeDialTarget(dialE164) {
  if (typeof dialE164 !== 'string' || !/^\+[1-9]\d{6,14}$/.test(dialE164)) throw unsafe('dialE164 must be a valid E.164 number');
  const digits = dialE164.slice(1);
  if (digits.length < MIN_DIAL_DIGITS) throw unsafe('Short codes cannot be dialled');
  const parsed = parsePhoneNumberFromString(dialE164);
  if (!parsed?.isValid()) throw unsafe('dialE164 is not a valid phone number');
  const national = String(parsed.nationalNumber);
  if (national.length < MIN_DIAL_DIGITS) throw unsafe('Short codes cannot be dialled');
  if (EMERGENCY_BLOCKLIST.includes(national) || EMERGENCY_BLOCKLIST.includes(digits)) throw unsafe('That is a real emergency number and cannot be a dial target');
  return true;
}

/** Message for contacts. Voice <= 450 chars, SMS <= 320. */
export function buildContactMessage({ crisis, custom, trackUrl }) {
  const base = (custom ?? '').trim() || (crisis ? `Mine emergency at MG Demo Colliery. ${crisis.reason || 'A crisis is active'}. Zones: ${crisis.zoneCodes.join(', ')}.` : 'Mine Guardian test message.');
  return {
    voice: `${base} Please respond.`.slice(0, VOICE_MAX),
    sms: `${base}${trackUrl ? ` Status: ${trackUrl}` : ''}`.slice(0, SMS_MAX),
  };
}
