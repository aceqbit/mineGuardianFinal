import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'modules');

test('every module folder with an index.js exports { name, basePath }', async () => {
  for (const d of fs.readdirSync(dir)) {
    const idx = path.join(dir, d, 'index.js');
    if (!fs.existsSync(idx)) continue;
    const m = (await import(pathToFileURL(idx).href)).default;
    assert.ok(m?.name && m?.basePath?.startsWith('/'), `module ${d} must export { name, basePath }`);
  }
});
