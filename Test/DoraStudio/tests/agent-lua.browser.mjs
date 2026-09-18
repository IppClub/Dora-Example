import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const wasm = await readFile(new URL('../packages/agent-contracts/dist/lua/syntax.mjs', import.meta.url));
const worker = `import createLua from '/syntax.mjs';
const ready = createLua();
self.onmessage = async event => {
  const {id, source} = event.data;
  const module = await ready;
  const bytes = new TextEncoder().encode(source);
  const pointer = module._malloc(Math.max(1, bytes.length));
  try {
    module.HEAPU8.set(bytes, pointer);
    self.postMessage({id, type: 'started'});
    const status = module._syntax_check(pointer, bytes.length);
    const message = status ? module.cwrap('syntax_error', 'string', [])() : '';
    self.postMessage({id, type: 'result', status, message});
  } finally { module._free(pointer); module._syntax_close(); }
};`;
const server = createServer((req, res) => {
  if (req.url === '/') { res.setHeader('content-type', 'text/html'); res.end('<title>Lua Worker verification</title>'); }
  else if (req.url === '/worker.mjs' || req.url === '/syntax.mjs') {
    res.setHeader('content-type', 'text/javascript'); res.end(req.url === '/worker.mjs' ? worker : wasm);
  } else { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const result = await page.evaluate(async () => {
    let ticks = 0;
    const timer = setInterval(() => ticks++, 5);
    const worker = new Worker('/worker.mjs', { type: 'module' });
    let sequence = 0;
    const check = source => new Promise((resolve, reject) => {
      const id = ++sequence;
      const timeout = setTimeout(() => { worker.terminate(); reject(new Error('Lua parser timeout')); }, 10000);
      worker.onerror = event => { clearTimeout(timeout); reject(new Error(event.message)); };
      worker.onmessage = event => {
        if (event.data.id !== id || event.data.type !== 'result') return;
        clearTimeout(timeout); resolve(event.data);
      };
      worker.postMessage({ id, source });
    });
    try {
      const noExecution = await check('while true do end');
      const invalid = await check('local =');
      const recovered = await check('return "中文"');
      const embeddedNul = await check('return 1\0invalid');
      const before = ticks;
      const large = await check('local x = 0\n' + 'x = x + 1\n'.repeat(300000));
      return { noExecution, invalid, recovered, embeddedNul, large, ticks: ticks - before };
    } finally { clearInterval(timer); worker.terminate(); }
  });
  assert.equal(result.noExecution.status, 0);
  assert.notEqual(result.invalid.status, 0);
  assert.match(result.invalid.message, /check.*1/);
  assert.equal(result.recovered.status, 0);
  assert.notEqual(result.embeddedNul.status, 0);
  assert.equal(result.large.status, 0);
  assert.ok(result.ticks > 0, JSON.stringify(result));
  assert.deepEqual(errors, []);
  console.log(`PASS Chrome ${browser.version()}: actual Lua Wasm Worker syntax, no execution, errors/recovery, UTF-8/NUL; ${result.ticks} page heartbeats during large parse`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
