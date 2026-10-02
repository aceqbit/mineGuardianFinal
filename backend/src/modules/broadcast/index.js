import { Router } from 'express';
import { z } from 'zod';
import { authenticate, requireRole } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate, objectId, isoDate } from '../../core/validate.js';
import { registerClientHandler } from '../../core/socket.js';
import { catchUp, handleAck, handleReply, history, repliesFor, sendBroadcast, startAckFlusher } from './broadcast.service.js';

const router = Router();

const sendBody = z
  .object({
    text: z.string().trim().min(1).max(280),
    priority: z.enum(['INFO', 'URGENT', 'EMERGENCY']),
    scope: z.enum(['ALL', 'ZONE', 'ROLE']),
    zoneId: objectId.optional(),
    role: z.enum(['miner', 'supervisor', 'admin']).optional(),
  })
  .strict()
  .superRefine((b, ctx) => {
    if (b.scope === 'ZONE' && !b.zoneId) ctx.addIssue({ code: 'custom', path: ['zoneId'], message: 'zoneId is required for ZONE' });
    if (b.scope === 'ROLE' && !b.role) ctx.addIssue({ code: 'custom', path: ['role'], message: 'role is required for ROLE' });
  });

router.post('/', authenticate(), requireRole('admin', 'supervisor'), validate({ body: sendBody }), asyncHandler(async (req, res) => res.status(201).json(await sendBroadcast(req.user, req.body))));
router.get('/', authenticate(), validate({ query: z.object({ since: isoDate.optional() }) }), asyncHandler(async (req, res) => res.json(await catchUp(req.user, req.query.since))));
router.get('/history', authenticate(), requireRole('admin', 'supervisor'), asyncHandler(async (req, res) => res.json(await history(req.user))));
router.get('/replies', authenticate(), requireRole('admin', 'supervisor'), validate({ query: z.object({ broadcastId: objectId.optional() }) }), asyncHandler(async (req, res) => res.json(await repliesFor(req.user, req.query.broadcastId))));

function init() {
  registerClientHandler('broadcast:ack', handleAck);
  registerClientHandler('broadcast:reply', handleReply);
  startAckFlusher();
}

export default { name: 'broadcast', basePath: '/api/broadcasts', router, init };
