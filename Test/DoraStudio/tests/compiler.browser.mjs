import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const buildRoot = fileURLToPath(new URL('../../Tools/dora-dora/build/', import.meta.url));
const declarations = await Promise.all(['Dora.d.ts', 'es6-subset.d.ts', 'lua.d.ts', 'jsx.d.ts'].map(async name => ({
  file: `/engine/Dora/en/${name}`, moduleName: name.replace('.d.ts', ''),
  content: await readFile(new URL(`../../Assets/Script/Lib/Dora/en/${name}`, import.meta.url), 'utf8'),
})));
const lualib = { file: 'lualib_bundle.lua', content: await readFile(new URL('../../Assets/Script/Lib/lualib_bundle.lua', import.meta.url), 'utf8') };
const makeJob = (id, root, value, missing = false) => ({
  id, file: `${root}/main.ts`, projectRoot: root,
  content: 'import { Vec2 } from "Dora"; import { value } from "logic/value"; export const result = Vec2(value, 2);',
  files: [...declarations, lualib, ...missing ? [] : [{ file: `${root}/logic/value.ts`, content: `export const value = ${value};` }]],
});
const jobs = [makeJob(1, '/project-a', 11), makeJob(2, '/project-a', 22), makeJob(3, '/project-b', 33),
  makeJob(4, '/project-a', 0, true), makeJob(5, '/project-a', 44)];
jobs.push({id: 6, file: '/plain/main.ts', projectRoot: '/plain',
 content: 'const value = 1; function drawBaby() { return value; } drawBaby();', files: [...declarations, lualib]});
jobs.push({id: 7, file: '/plain-tsx/main.tsx', projectRoot: '/plain-tsx',
 content: 'const value = 1; function drawBaby() { return value; } drawBaby();', files: [...declarations, lualib]});
const expectedCount = jobs.length;
const results = [];
const forbidden = [];
const errors = [];
let finish;
const done = new Promise(resolve => { finish = resolve; });
const server = createServer(async (req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  const json = data => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(data)); };
  try {
    if (pathname === '/status') return json({platform: 'Linux'});
    if (pathname === '/compiler/ready') return json({ success: true });
    if (pathname === '/compiler/poll') return json({ success: true, job: jobs.shift() });
    if (pathname === '/compiler/result') {
      let body = '';
      for await (const chunk of req) body += chunk;
      results.push(JSON.parse(body));
      json({ success: true });
      if (results.length === expectedCount) finish();
      return;
    }
    if (req.method !== 'GET') {
      forbidden.push(pathname); res.writeHead(403); res.end('No native services'); return;
    }
    if (pathname === '/heavy-assets.json') return json(JSON.parse(await readFile(resolve(buildRoot, 'heavy-assets.json'), 'utf8')));
    const path = resolve(buildRoot, `.${decodeURIComponent(pathname)}`);
    if (!path.startsWith(resolve(buildRoot) + sep)) { res.writeHead(403); res.end(); return; }
    const content = await readFile(path);
    const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm' };
    res.writeHead(200, { 'content-type': mime[extname(path)] || 'application/octet-stream' });
    res.end(content);
  } catch {
    res.writeHead(404); res.end();
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ headless: true,
  ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}),
});
let timeout;
try {
  const page = await browser.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto(`http://127.0.0.1:${server.address().port}/compiler.html`);
  await Promise.race([done, new Promise((_, reject) => {
    timeout = setTimeout(() => reject(new Error(`Compiler timed out: ${JSON.stringify({ results, errors })}`)), 30000);
  })]);
  assert.deepEqual(results.map(result => [result.id, result.success]), [[1, true], [2, true], [3, true], [4, false], [5, true], [6, true], [7, true]], JSON.stringify(results));
  for (const result of results.filter(result => result.success && result.id <= 5)) {
    assert.match(result.luaCode, /-- \[ts\]: main.ts/);
    assert.match(result.luaCode, /require\("Dora"\)/);
    assert.match(result.luaCode, /logic.value/);
  }
  for (const result of results.filter(result => result.id >= 6)) {
    assert.match(result.luaCode, /local value = 1/);
    assert.match(result.luaCode, /local function drawBaby/);
    assert.doesNotMatch(result.luaCode, /^value =|^function drawBaby/m);
  }
  assert.match(results[3].message, /Cannot find module/);
  assert.deepEqual(forbidden, [], 'snapshot compiler must not call native file services');
  assert.deepEqual(errors.filter(message => !message.includes('404')), []);
  console.log(`PASS Chrome ${browser.version()}: 7 real native-IDE snapshot jobs including no-import TS/TSX locals, multi-project, missing dependency and recovery; zero native file requests.`);
} finally {
  clearTimeout(timeout);
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
