import http from 'node:http';
import { env } from './config/env.js';
import { logger } from './core/logger.js';
import { connectDb, disconnectDb } from './core/db.js';
import { initSocket } from './core/socket.js';
import { logDevBypassWarning } from './core/auth.js';
import { createApp, loadModules, mountDevRoutes, finalizeApp } from './app.js';

async function main() {
  await connectDb(env.MONGODB_URI);
  const app = createApp();
  const server = http.createServer(app);
  const io = initSocket(server);
  logDevBypassWarning();
  mountDevRoutes(app);
  await loadModules(app, io);
  finalizeApp(app);

  server.listen(env.PORT, '0.0.0.0', () => logger.info(`Mine Guardian API on 0.0.0.0:${env.PORT} (${env.NODE_ENV})`));

  const shutdown = async (sig) => {
    logger.info(`${sig} received, shutting down`);
    io.close();
    server.close(async () => {
      await disconnectDb().catch(() => {});
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 5000).unref();
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((err) => {
  logger.error({ err }, 'fatal startup error');
  process.exit(1);
});
