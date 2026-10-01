import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { AppError, asyncHandler } from '../../core/errors.js';
import { validate, idParams, objectId } from '../../core/validate.js';
import { audit } from '../../core/audit.js';
import { Zone } from '../../models/Zone.js';
import { User } from '../../models/User.js';
import { MineLayout } from '../../models/MineLayout.js';

const router = Router();

const phoneMasked = (e164) => (e164 ? `${e164.slice(0, 3)}******${e164.slice(-4)}` : '');

const publicZone = (z_) => ({ id: z_.id, _id: z_.id, code: z_.code, name: z_.name, mineName: z_.mineName });

router.get(
  '/zones',
  asyncHandler(async (_req, res) => {
    const zones = await Zone.find().sort({ code: 1 });
    res.json(zones.map(publicZone));
  }),
);

router.get(
  '/zones/:id',
  authenticate(),
  validate({ params: idParams }),
  asyncHandler(async (req, res) => {
    const zone = await Zone.findById(req.params.id);
    if (!zone) throw new AppError(404, 'NOT_FOUND', 'Zone not found');
    const sups = await User.find({ _id: { $in: zone.supervisorIds } }).select('fullName phone.e164');
    res.json({
      ...publicZone(zone),
      requiredPpe: zone.requiredPpe,
      shiftWindows: zone.shiftWindows,
      supervisors: sups.map((s) => ({ id: s.id, fullName: s.fullName, phoneMasked: phoneMasked(s.phone?.e164) })),
    });
  }),
);

router.put(
  '/zones/:id/supervisors',
  authenticate(),
  requireRole('admin'),
  validate({ params: idParams, body: z.object({ supervisorIds: z.array(objectId) }).strict() }),
  asyncHandler(async (req, res) => {
    const zone = await Zone.findById(req.params.id);
    if (!zone) throw new AppError(404, 'NOT_FOUND', 'Zone not found');
    const ids = [...new Set(req.body.supervisorIds)];
    const sups = await User.find({ _id: { $in: ids } });
    if (sups.length !== ids.length || sups.some((s) => s.role !== 'supervisor')) {
      throw new AppError(400, 'INVALID_SUPERVISORS', 'Every id must be an existing supervisor');
    }
    // A supervisor supervises one zone: remove them from any other zone's list.
    await Zone.updateMany({ _id: { $ne: zone._id } }, { $pull: { supervisorIds: { $in: ids } } });
    zone.supervisorIds = ids;
    await zone.save();
    await User.updateMany({ _id: { $in: ids } }, { $set: { zoneId: zone._id } });
    await audit(req.user, 'ZONE_SUPERVISORS_SET', 'zone', zone._id, { supervisorIds: ids });
    res.json(zone.toJSON());
  }),
);

router.get(
  '/layout',
  authenticate(),
  asyncHandler(async (req, res) => {
    const layout = await MineLayout.findOne().sort({ version: -1 });
    if (!layout) throw new AppError(404, 'NOT_FOUND', 'No layout');
    const etag = `"${layout.version}"`;
    res.set('ETag', etag);
    res.set('Cache-Control', 'private, max-age=0, must-revalidate');
    if (req.headers['if-none-match'] === etag || req.headers['if-none-match'] === String(layout.version)) {
      return res.status(304).end();
    }
    res.json({ version: layout.version, anchor: layout.anchor, geojson: layout.geojson });
  }),
);

export default { name: 'zones', basePath: '/api', router };
