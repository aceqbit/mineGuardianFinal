import { z } from 'zod';
import mongoose from 'mongoose';

/**
 * validate({ body, query, params }) -> express middleware.
 * Parsed (and coerced) values replace req.body / req.query / req.params.
 */
export function validate(schemas) {
  return (req, res, next) => {
    try {
      for (const part of ['params', 'query', 'body']) {
        if (schemas[part]) {
          const parsed = schemas[part].parse(req[part] ?? {});
          if (part === 'query') {
            Object.defineProperty(req, 'query', { value: parsed, writable: true, configurable: true });
          } else {
            req[part] = parsed;
          }
        }
      }
      next();
    } catch (e) {
      next(e);
    }
  };
}

export const objectId = z.string().refine((v) => mongoose.isValidObjectId(v) && String(v).length === 24, 'Invalid id');
export const isoDate = z.string().refine((v) => !Number.isNaN(Date.parse(v)), 'Invalid ISO date');
export const idParams = z.object({ id: objectId });
