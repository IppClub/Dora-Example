import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { build } from 'esbuild';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const bundle = (await build({ stdin: { contents: `export {createSnapshotListBackend} from './snapshot-list.js';
export {createSearchHandlers, validateSearchInput} from './search-tools.js';
export {getToolDefinition} from './index.js';
export {executeAgentToolDefinition} from './executor.js';`, resolveDir: new URL('../packages/agent-contracts/dist/', import.meta.url).pathname },
  bundle: true, format: 'esm', platform: 'browser', write: false })).outputFiles[0].text;
const wasm = await readFile(new URL('../packages/agent-contracts/dist/glob/matcher.mjs', import.meta.url));
const server = createServer((req, res) => {
  if (req.url === '/') { res.setHeader('content-type', 'text/html'); res.end('<title>Agent glob verification</title>'); }
  else if (req.url === '/api.js' || req.url === '/matcher.mjs') { res.setHeader('content-type', 'text/javascript'); res.end(req.url === '/api.js' ? bundle : wasm); }
  else { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const result = await page.evaluate(async () => {
    const api = await import('/api.js');
    const { default: createMatcher } = await import('/matcher.mjs');
    const snapshot = { version: 1, projectId: 'A', revision: 0, entry: 'main.ts', files:
      ['main.ts', 'nested/a.ts', 'nested/a.lua', 'nested/.cache/hidden.ts', 'node_modules/lib.ts', '.agent/private.ts', '中文/游戏.ts']
        .map(path => ({ path, kind: 'text', text: '' })) };
    const pending = api.createSnapshotListBackend(snapshot, createMatcher);
    snapshot.files.push({ path: 'late.ts', kind: 'text', text: '' });
    const listFiles = await pending;
    const definition = { ...api.getToolDefinition('glob_files'), validateInput: input => api.validateSearchInput('glob_files', input),
      handler: api.createSearchHandlers({ listFiles }).glob_files };
    const context = { role: 'main', workMode: 'code', workingDir: 'A', disabledAgentTools: [],
      cancellation: { isCancelled: () => false, reason: () => undefined } };
    const run = (input, ctx = context) => api.executeAgentToolDefinition(definition, input, ctx, { searchDoraDocLimitMax: 20 });
    return { recursive: await run({ globs: ['**/*.ts'] }), root: await run({ globs: ['*.ts'] }),
      nested: await run({ path: 'nested', globs: ['**'] }), limited: await run({ globs: ['**/*.ts'], maxEntries: 1 }),
      foreign: await run({}, { ...context, workingDir: 'B' }), traversal: await run({ path: '../' }) };
  });
  assert.deepEqual(result.recursive.output.files, ['main.ts', 'nested/a.ts', '中文/游戏.ts']);
  assert.deepEqual(result.root.output.files, ['main.ts']);
  assert.deepEqual(result.nested.output.files, ['a.ts', 'a.lua']);
  assert.equal(result.limited.output.truncated, true);
  assert.equal(result.limited.output.totalEntries, 3);
  assert.equal(result.foreign.output.success, false);
  assert.equal(result.traversal.output.success, false);
  assert.deepEqual(errors, []);
  console.log(`PASS Chrome ${browser.version()}: original Agent glob executor to real Wasm snapshot listing, filters, truncation, mutation and project isolation`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
