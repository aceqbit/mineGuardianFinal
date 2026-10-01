// In-process job queue: concurrency 3, 2 retries per job (backoff 2 s then 6 s), deduped by entity id.
import { logger } from '../../core/logger.js';

export function createQueue({ concurrency = 3, retries = 2, delaysMs = [2000, 6000], onError = () => {} } = {}) {
  const pending = [];
  const queued = new Set(); // ids waiting or running
  let running = 0;
  const stats = { lastLatencyMs: null, processed: 0, failed: 0 };

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  async function runJob(job) {
    let lastErr;
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const t0 = Date.now();
        const res = await job.fn();
        stats.lastLatencyMs = Date.now() - t0;
        stats.processed++;
        return res;
      } catch (err) {
        lastErr = err;
        if (attempt < retries) await sleep(delaysMs[attempt] ?? 6000);
      }
    }
    stats.failed++;
    onError(job.id, lastErr);
    logger.error({ err: lastErr?.message, id: job.id }, 'AI job failed after retries');
  }

  function pump() {
    while (running < concurrency && pending.length) {
      const job = pending.shift();
      running++;
      runJob(job).finally(() => {
        running--;
        queued.delete(job.id);
        pump();
      });
    }
  }

  return {
    /** Returns false when a job for this id is already waiting or running (deduped). */
    enqueue(id, fn) {
      if (queued.has(id)) return false;
      queued.add(id);
      pending.push({ id, fn });
      pump();
      return true;
    },
    get depth() {
      return pending.length + running;
    },
    stats,
    has: (id) => queued.has(id),
  };
}
