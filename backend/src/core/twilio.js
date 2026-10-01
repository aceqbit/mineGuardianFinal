import { v4 as uuid } from 'uuid';
import { parsePhoneNumberFromString } from 'libphonenumber-js/max';
import twilioLib from 'twilio';
import { env } from '../config/env.js';
import { logger, maskPhone } from './logger.js';

let client;
const hasCreds = () => Boolean(env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM_NUMBER);
const getClient = () => (client ??= twilioLib(env.TWILIO_ACCOUNT_SID, env.TWILIO_AUTH_TOKEN));
const dry = () => env.TWILIO_DRY_RUN || !hasCreds();

const validE164 = (n) => {
  if (typeof n !== 'string' || !/^\+[1-9]\d{6,14}$/.test(n)) return false;
  return Boolean(parsePhoneNumberFromString(n));
};

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export function buildTwiml(text) {
  const t = esc(text);
  return `<Response><Say language="en-IN">${t}</Say><Pause length="1"/><Say language="en-IN">${t}</Say></Response>`;
}

export async function sendSms(to, body) {
  try {
    if (!validE164(to)) return { error: 'INVALID_E164' };
    if (dry()) {
      logger.info(`[TWILIO DRY RUN] SMS to ${maskPhone(to)}: ${String(body).slice(0, 120)}`);
      return { sid: `DRYRUN-${uuid()}`, dryRun: true };
    }
    const m = await getClient().messages.create({ to, from: env.TWILIO_FROM_NUMBER, body });
    return { sid: m.sid };
  } catch (err) {
    logger.warn({ err: err.message }, 'twilio sms failed');
    return { error: err.message };
  }
}

export async function makeCall(to, text) {
  try {
    if (!validE164(to)) return { error: 'INVALID_E164' };
    if (dry()) {
      logger.info(`[TWILIO DRY RUN] CALL to ${maskPhone(to)}: ${String(text).slice(0, 120)}`);
      return { sid: `DRYRUN-${uuid()}`, dryRun: true };
    }
    const c = await getClient().calls.create({ to, from: env.TWILIO_FROM_NUMBER, twiml: buildTwiml(text) });
    return { sid: c.sid };
  } catch (err) {
    logger.warn({ err: err.message }, 'twilio call failed');
    return { error: err.message };
  }
}
