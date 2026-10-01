import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { env } from './config/env.js';
import { logger } from './core/logger.js';
import { bus } from './core/bus.js';
import { emitTo } from './core/socket.js';
import { errorHandler, notFound, AppError } from './core/errors.js';
import { BUS_EVENTS, SOCKET_EVENTS } from './contracts/events.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const modulesDir = path.join(here, 'modules');

export function createApp() {
  const app = express();
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGINS === '*' ? true : env.CORS_ORIGINS.split(',') }));
  app.use(express.json({ limit: '1mb' }));
  app.use((req, res, next) => {
    const t0 = Date.now();
    res.on('finish', () => logger.info(`${req.method} ${req.originalUrl.split('?')[0]} ${res.statusCode} ${Date.now() - t0}ms`));
    next();
  });
  app.use('/api/auth', rateLimit({ windowMs: 60_000, limit: 30, standardHeaders: true, legacyHeaders: false }));
  app.get('/api/health', (_req, res) => res.json({ ok: true, time: new Date().toISOString() }));
  return app;
}

export async function loadModules(app, io) {
  const loaded = [];
  const dirs = fs.existsSync(modulesDir) ? fs.readdirSync(modulesDir).sort() : [];
  for (const dir of dirs) {
    const indexPath = path.join(modulesDir, dir, 'index.js');
    if (!fs.existsSync(indexPath)) continue;
    try {
      const mod = (await import(pathToFileURL(indexPath).href)).default;
      if (!mod?.name || !mod?.basePath) throw new Error('module must export { name, basePath }');
      if (mod.router) app.use(mod.basePath, mod.router);
      loaded.push(mod);
    } catch (err) {
      logger.error({ err: err.message }, `module ${dir} failed to load; skipped`);
    }
  }
  for (const mod of loaded) {
    try {
      await mod.init?.({ app, io, bus, env, logger });
    } catch (err) {
      logger.error({ err: err.message }, `module ${mod.name} init failed`);
    }
  }
  logger.info(`${loaded.length} modules loaded${loaded.length ? `: ${loaded.map((m) => m.name).join(', ')}` : ''}`);
  return loaded;
}

export function mountDevRoutes(app) {
  if (!env.isDev) return;
  const emitBody = z.object({ event: z.string(), rooms: z.array(z.string()).min(1), data: z.record(z.any()).default({}) });
  const busBody = z.object({ event: z.string(), data: z.record(z.any()).default({}) });
  app.post('/dev/emit', (req, res, next) => {
    try {
      const b = emitBody.parse(req.body);
      if (!SOCKET_EVENTS.serverToClient.includes(b.event)) throw new AppError(400, 'UNKNOWN_EVENT', `Unknown socket event: ${b.event}`);
      emitTo(b.rooms, b.event, b.data);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });
  app.post('/dev/bus', (req, res, next) => {
    try {
      const b = busBody.parse(req.body);
      if (!BUS_EVENTS.includes(b.event)) throw new AppError(400, 'UNKNOWN_EVENT', `Unknown bus event: ${b.event}`);
      bus.publish(b.event, b.data);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });
}

export function finalizeApp(app) {
  app.use(notFound);
  app.use(errorHandler);
}
