import { Router } from 'express';
import fs from 'node:fs';
import nodePath from 'node:path';
import { env } from '../../config/env.js';
import { resolveLocalToken } from '../../core/storage.js';

const router = Router();
const TYPES = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.pdf': 'application/pdf' };
const gone = (res, message) => res.status(404).json({ error: { code: 'NOT_FOUND', message, details: null } });

/** Serves files for STORAGE_DRIVER=local only. The signed token is the authorisation, like a Firebase signed URL. */
router.get('/:token', (req, res) => {
  if (env.STORAGE_DRIVER !== 'local') return gone(res, 'Not available');
  const r = resolveLocalToken(req.params.token);
  if (!r || !fs.existsSync(r.file)) return gone(res, 'Link expired or invalid');
  res.set('Cache-Control', 'private, max-age=300');
  res.type(TYPES[nodePath.extname(r.file).toLowerCase()] ?? 'application/octet-stream');
  return fs.createReadStream(r.file).pipe(res);
});

export default { name: 'files', basePath: '/files', router };
