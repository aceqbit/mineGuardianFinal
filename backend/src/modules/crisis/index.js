import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { AppError, asyncHandler } from '../../core/errors.js';
import { validate, objectId } from '../../core/validate.js';
import { logger } from '../../core/logger.js';
import { subscribe } from '../../core/bus.js';
import { Zone } from '../../models/Zone.js';
import { activate, activateFromSos, activeForClient, addTimeline, getActive, getReport, initEngine, markAccounted, onGps, onSosCancelled, recompute, resolve, setBlockedEdge } from './crisis.engine.js';

const router = Router();
const idParams = z.object({ id: objectId });
const admin = [authenticate(), requireRole('admin')];
const staff = [authenticate(), requireRole('supervisor', 'admin')];

function requireActive(req) {
  const c = getActive();
  if (!c || String(c._id) !== String(req.params.id)) throw new AppError(404, 'NOT_FOUND', 'No such active crisis');
  return c;
}

function requireZoneStaff(req, c) {
  if (req.user.role === 'supervisor' && !c.zoneIds.map(String).includes(String(req.user.zoneId))) throw new AppError(403, 'FORBIDDEN_ROLE', 'Not your zone');
}

router.get('/active', authenticate(), asyncHandler(async (req, res) => res.json(await activeForClient(req.user))));

router.post(
  '/activate',
  ...admin,
  validate({ body: z.object({ zoneIds: z.array(objectId).min(1), reason: z.string().trim().min(10).max(300) }).strict() }),
  asyncHandler(async (req, res) => {
    const zones = await Zone.countDocuments({ _id: { $in: req.body.zoneIds } });
    if (zones !== new Set(req.body.zoneIds).size) throw new AppError(400, 'VALIDATION_ERROR', 'Unknown zone', [{ path: 'zoneIds', message: 'Unknown zone' }]);
    const c = await activate({ trigger: { type: 'MANUAL', by: String(req.user._id) }, zoneIds: req.body.zoneIds, reason: req.body.reason, actor: req.user });
    res.status(201).json({ crisisId: String(c._id) });
  }),
);

router.post(
  '/:id/resolve',
  ...admin,
  validate({
    params: idParams,
    body: z.object({ falseAlarm: z.boolean(), note: z.string().max(1000), checklist: z.object({ allAccounted: z.boolean(), hazardsContained: z.boolean() }).partial().optional() }).strict(),
  }),
  asyncHandler(async (req, res) => res.json(await resolve(req.user, req.params.id, req.body))),
);

router.post(
  '/:id/accounted',
  ...staff,
  validate({ params: idParams, body: z.object({ workerId: objectId, status: z.enum(['SAFE', 'MISSING', 'INJURED', 'UNKNOWN']) }).strict() }),
  asyncHandler(async (req, res) => {
    const c = requireActive(req);
    requireZoneStaff(req, c);
    await markAccounted(req.body.workerId, req.body.status, req.user);
    res.json({ ok: true });
  }),
);

router.get(
  '/:id/report',
  ...staff,
  validate({ params: idParams }),
  asyncHandler(async (req, res) => res.json(await getReport(req.params.id))),
);

router.post(
  '/:id/recompute',
  ...admin,
  validate({ params: idParams }),
  asyncHandler(async (req, res) => {
    requireActive(req);
    const r = await recompute('manual');
    res.json({ ok: true, features: r?.collection?.features?.length ?? 0 });
  }),
);

router.patch(
  '/:id/edges/:edgeId',
  ...admin,
  validate({ params: z.object({ id: objectId, edgeId: z.string().min(1).max(64) }), body: z.object({ blocked: z.boolean() }).strict() }),
  asyncHandler(async (req, res) => {
    requireActive(req);
    await setBlockedEdge(req.params.edgeId, req.body.blocked);
    res.json({ ok: true, blocked: req.body.blocked });
  }),
);

router.get(
  '/:id/routes',
  ...staff,
  validate({ params: idParams }),
  asyncHandler(async (req, res) => {
    const c = requireActive(req);
    requireZoneStaff(req, c);
    const { getRoutes } = await import('./crisis.engine.js');
    res.json(getRoutes() ?? { type: 'FeatureCollection', features: [] });
  }),
);

router.post(
  '/:id/assign-route',
  ...admin,
  validate({ params: idParams, body: z.object({ workerId: objectId, exitId: z.string().min(1).max(64) }).strict() }),
  asyncHandler(async (req, res) => {
    const c = requireActive(req);
    const { assignRoute } = await import('./rerouter/rerouter.service.js').catch(() => ({}));
    if (!assignRoute) throw new AppError(501, 'NOT_AVAILABLE', 'Routing is not available');
    const out = await assignRoute({ crisis: c, workerId: req.body.workerId, exitId: req.body.exitId, by: req.user });
    addTimeline(`Admin assigned a worker to exit ${req.body.exitId}`);
    res.json(out);
  }),
);

function init() {
  subscribe('SosTriggered', async ({ data }) => { await activateFromSos(data.sosId); });
  subscribe('SosCancelled', async ({ data }) => { await onSosCancelled(data.sosId); });
  subscribe('CrisisRequested', async ({ data }) => {
    await activate({ trigger: data.trigger, zoneIds: data.zoneIds, reason: data.reason ?? '' });
  });
  subscribe('GpsUpdated', async ({ data }) => { await onGps(data); });
  return initEngine().then(() => logger.info('crisis engine ready'));
}

export default { name: 'crisis', basePath: '/api/crisis', router, init };
