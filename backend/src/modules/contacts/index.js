import { Router } from 'express';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { authenticate, requireRole } from '../../core/auth.js';
import { AppError, asyncHandler } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { validate, objectId } from '../../core/validate.js';
import { makeCall, sendSms } from '../../core/twilio.js';
import { EmergencyContact } from '../../models/EmergencyContact.js';
import { Zone } from '../../models/Zone.js';
import { getActive } from '../crisis/crisis.engine.js';
import { assertSafeDialTarget, buildContactMessage } from './contacts.logic.js';

const router = Router();
const staff = [authenticate(), requireRole('supervisor', 'admin')];
const admin = [authenticate(), requireRole('admin')];
const idParams = z.object({ id: objectId });
const messageBody = z.object({ message: z.string().trim().max(300).optional() }).strict();

/** Only admins ever see dialE164. Everyone else sees what a person would dial. */
const view = (c, user) => ({ id: String(c._id), category: c.category, name: c.name, displayNumber: c.displayNumber, notes: c.notes ?? '', order: c.order, active: c.active, ...(user.role === 'admin' ? { dialE164: c.dialE164 } : {}) });

async function messages(custom) {
  const crisis = getActive();
  let ctx = null;
  let trackUrl = null;
  if (crisis) {
    const zones = await Zone.find({ _id: { $in: crisis.zoneIds } });
    ctx = { reason: crisis.reason, zoneCodes: zones.map((z) => z.code) };
    trackUrl = `${env.PUBLIC_BASE_URL}/public/track/${crisis.shareToken}`;
  }
  return buildContactMessage({ crisis: ctx, custom, trackUrl });
}

async function findContact(id) {
  const c = await EmergencyContact.findById(id);
  if (!c || !c.active) throw new AppError(404, 'NOT_FOUND', 'Contact not found');
  return c;
}

router.get('/', ...staff, asyncHandler(async (req, res) => res.json((await EmergencyContact.find({ active: true }).sort({ order: 1, name: 1 })).map((c) => view(c, req.user)))));

router.put(
  '/:id',
  ...admin,
  validate({
    params: idParams,
    body: z.object({ name: z.string().trim().min(2).max(80).optional(), displayNumber: z.string().trim().min(2).max(40).optional(), dialE164: z.string().optional(), notes: z.string().max(200).optional(), active: z.boolean().optional() }).strict(),
  }),
  asyncHandler(async (req, res) => {
    if (req.body.dialE164 !== undefined) assertSafeDialTarget(req.body.dialE164);
    const c = await EmergencyContact.findByIdAndUpdate(req.params.id, { $set: req.body }, { new: true });
    if (!c) throw new AppError(404, 'NOT_FOUND', 'Contact not found');
    await audit(req.user, 'CONTACT_UPDATED', 'emergency_contact', c._id, { fields: Object.keys(req.body) });
    res.json(view(c, req.user));
  }),
);

router.post(
  '/notify-all',
  ...admin,
  validate({ body: messageBody }),
  asyncHandler(async (req, res) => {
    const { voice, sms } = await messages(req.body.message);
    const all = await EmergencyContact.find({ active: true });
    for (const c of all) assertSafeDialTarget(c.dialE164); // refuse the whole batch if any stored target is unsafe
    const results = await Promise.allSettled(all.flatMap((c) => [makeCall(c.dialE164, voice), sendSms(c.dialE164, sms)]));
    await audit(req.user, 'CONTACTS_NOTIFIED_ALL', 'emergency_contact', '', { contacts: all.length });
    res.json({ contacts: all.length, ok: results.filter((r) => r.status === 'fulfilled' && !r.value?.error).length, dryRun: env.TWILIO_DRY_RUN });
  }),
);

router.post(
  '/:id/call',
  ...staff,
  validate({ params: idParams, body: messageBody }),
  asyncHandler(async (req, res) => {
    const c = await findContact(req.params.id);
    assertSafeDialTarget(c.dialE164);
    const { voice } = await messages(req.body.message);
    const r = await makeCall(c.dialE164, voice);
    await audit(req.user, 'CONTACT_CALLED', 'emergency_contact', c._id, { category: c.category, dryRun: Boolean(r.dryRun) });
    if (r.error) throw new AppError(502, 'CALL_FAILED', 'The call could not be placed');
    res.json({ ok: true, dryRun: Boolean(r.dryRun) });
  }),
);

router.post(
  '/:id/sms',
  ...staff,
  validate({ params: idParams, body: messageBody }),
  asyncHandler(async (req, res) => {
    const c = await findContact(req.params.id);
    assertSafeDialTarget(c.dialE164);
    const { sms } = await messages(req.body.message);
    const r = await sendSms(c.dialE164, sms);
    await audit(req.user, 'CONTACT_SMSED', 'emergency_contact', c._id, { category: c.category, dryRun: Boolean(r.dryRun) });
    if (r.error) throw new AppError(502, 'SMS_FAILED', 'The SMS could not be sent');
    res.json({ ok: true, dryRun: Boolean(r.dryRun) });
  }),
);

export default { name: 'contacts', basePath: '/api/contacts', router };
