import test from 'node:test';
import assert from 'node:assert/strict';
import { createQueue } from '../src/modules/ai-analyzer/jobs.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

test('dedupes by entity id while queued or running', async () => {
  const q = createQueue({ concurrency: 1, retries: 0 });
  let runs = 0;
  assert.equal(q.enqueue('a', async () => { runs++; await sleep(30); }), true);
  assert.equal(q.enqueue('a', async () => { runs++; }), false);
  await sleep(80);
  assert.equal(runs, 1);
  assert.equal(q.enqueue('a', async () => { runs++; }), true); // free again after completion
  await sleep(20);
  assert.equal(runs, 2);
});

test('runs at most `concurrency` jobs at once', async () => {
  const q = createQueue({ concurrency: 3, retries: 0 });
  let active = 0, peak = 0;
  for (let i = 0; i < 8; i++) {
    q.enqueue(`j${i}`, async () => {
      active++;
      peak = Math.max(peak, active);
      await sleep(15);
      active--;
    });
  }
  await sleep(120);
  assert.equal(peak, 3);
  assert.equal(q.depth, 0);
});

test('retries a failing job with backoff and then succeeds', async () => {
  const q = createQueue({ concurrency: 1, retries: 2, delaysMs: [5, 10] });
  let calls = 0;
  q.enqueue('r', async () => {
    calls++;
    if (calls < 3) throw new Error('flaky');
  });
  await sleep(80);
  assert.equal(calls, 3);
  assert.equal(q.stats.processed, 1);
  assert.equal(q.stats.failed, 0);
});

test('gives up after the retries and reports the failure', async () => {
  let reported;
  const q = createQueue({ concurrency: 1, retries: 1, delaysMs: [5], onError: (id) => { reported = id; } });
  q.enqueue('bad', async () => { throw new Error('nope'); });
  await sleep(60);
  assert.equal(reported, 'bad');
  assert.equal(q.stats.failed, 1);
});
