import { AuditLog } from '../models/AuditLog.js';
import { logger } from './logger.js';

/**
 * audit(actor, action, entity, entityId, meta). Never throws.
 * actor: a user doc / req.user / null (system).
 */
export async function audit(actor, action, entity = '', entityId = '', meta = {}) {
  try {
    await AuditLog.create({
      actorId: actor?._id ?? actor?.id ?? null,
      actorRole: actor?.role ?? 'system',
      action,
      entity,
      entityId: entityId ? String(entityId) : '',
      meta,
    });
  } catch (err) {
    logger.warn({ err: err.message, action }, 'audit write failed');
  }
}
