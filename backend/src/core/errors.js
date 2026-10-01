import { ZodError } from 'zod';
import multer from 'multer';
import { logger } from './logger.js';

export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

export function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `Route not found: ${req.method} ${req.path}`, details: null } });
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, next) {
  let status = 500;
  let code = 'INTERNAL';
  let message = 'Internal server error';
  let details = null;

  if (err instanceof AppError) {
    ({ status, code, message, details } = err);
  } else if (err instanceof ZodError) {
    status = 400;
    code = 'VALIDATION_ERROR';
    message = 'Invalid request';
    details = err.issues.map((i) => ({ path: i.path.join('.'), message: i.message }));
  } else if (err && err.code === 11000) {
    status = 409;
    code = 'DUPLICATE';
    const fields = Object.keys(err.keyPattern || err.keyValue || {});
    message = `Duplicate value${fields.length ? ` for ${fields.join(', ')}` : ''}`;
    details = { fields };
  } else if (err instanceof multer.MulterError) {
    status = 400;
    code = 'UPLOAD_ERROR';
    message = err.message;
  } else if (err && err.type === 'entity.parse.failed') {
    status = 400;
    code = 'VALIDATION_ERROR';
    message = 'Malformed JSON body';
  } else if (err && err.type === 'entity.too.large') {
    status = 413;
    code = 'PAYLOAD_TOO_LARGE';
    message = 'Request body too large';
  }

  if (status >= 500) logger.error({ err }, 'unhandled error');
  if (res.headersSent) return;
  res.status(status).json({ error: { code, message, details: details ?? null } });
}
