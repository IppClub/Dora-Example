import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, readdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { build } from 'esbuild';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const declarations = [];
async function collect(directory, prefix = '') {
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (item.isDirectory()) await collect(new URL(item.name + '/', directory), prefix + item.name + '/');
    else if (item.name.endsWith('.d.tl')) declarations.push({ path: prefix + item.name, kind: 'text', text: await readFile(new URL(item.name, directory), 'utf8') });
  }
}
await collect(new URL('../../Assets/Script/Lib/Dora/en/', import.meta.url));
const api = (await build({ stdin: { contents: `export {createTealCompiler} from './teal-compiler.js';
export {createTealWorkerBuild} from './teal-worker-client.js';
export {compileTealProject} from './teal-project.js';
export {createWorkerBuildBackend} from './worker-build.js';
export {createBuildHandler} from './build-tool.js';`, resolveDir: new URL('../packages/agent-contracts/dist/', import.meta.url).pathname }, bundle: true, format: 'esm', platform: 'browser', write: false })).outputFiles[0].text;
const wasm = await readFile(new URL('../packages/agent-contracts/dist/teal/compiler.mjs', import.meta.url));
const buildWorker = await readFile(new URL('../packages/agent-contracts/dist/teal/worker.mjs', import.meta.url));
const worker = `import {createTealCompiler} from '/api.js'; import createModule from '/compiler.mjs';
self.onmessage = async event => {
  const {snapshot, declarations} = event.data;
  let compiler;
  try {
    const pending = createTealCompiler(snapshot, declarations, createModule);
    snapshot.files[0].text = 'invalid mutated input';
    compiler = await pending;
    const checked = compiler.check('A', 'main.tl');
    const compiled = compiler.compile('A', 'main.tl');
    const lua = compiler.check('A', 'game.lua');
    const luaInvalid = compiler.check('A', 'broken.lua');
    const luaFiltered = compiler.check('A', 'unknown.lua');
    let foreignRejected = false;
    try { compiler.check('B', 'main.tl'); } catch { foreignRejected = true; }
    compiler.dispose();
    let disposedRejected = false;
    try { compiler.check('A', 'main.tl'); } catch { disposedRejected = true; }
    self.postMessage({checked, compiled, lua, luaInvalid, luaFiltered, foreignRejected, disposedRejected});
  } catch(error) { self.postMessage({error: String(error)}); }
  finally { compiler?.dispose(); }
};`;
const server = createServer((req, res) => {
  const content = { '/api.js': api, '/compiler.mjs': wasm, '/worker.mjs': worker, '/build-worker.mjs': buildWorker }[req.url];
  if (content) { res.setHeader('content-type', 'text/javascript'); res.end(content); }
  else if (req.url === '/') { res.setHeader('content-type', 'text/html'); res.end('<title>Teal Worker</title>'); }
  else { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const result = await page.evaluate(async declarations => {
    let ticks = 0; const timer = setInterval(() => ticks++, 5);
    const run = dependency => new Promise((resolve, reject) => {
      const worker = new Worker('/worker.mjs', { type: 'module' });
      const timeout = setTimeout(() => { worker.terminate(); reject(new Error('Teal worker timeout')); }, 20000);
      const finish = () => { clearTimeout(timeout); worker.terminate(); };
      worker.onerror = event => { finish(); reject(new Error(event.message)); };
      worker.onmessage = event => { finish(); resolve(event.data); };
      worker.postMessage({ declarations, snapshot: { version: 1, projectId: 'A', revision: 7, entry: 'main.tl', files: [
        { path: 'main.tl', kind: 'text', text: 'local dep = require("dep")\nlocal x: number = dep\nreturn x' },
        { path: 'dep.tl', kind: 'text', text: dependency },
        { path: 'game.lua', kind: 'text', text: 'while true do end' },
        { path: 'broken.lua', kind: 'text', text: 'local =' },
        { path: 'unknown.lua', kind: 'text', text: 'unknown_global()' },
      ] } });
    });
    try {
      const {createTealWorkerBuild, createWorkerBuildBackend, createBuildHandler, compileTealProject} = await import('/api.js');
      const compileNonTs = createTealWorkerBuild(() => new Worker('/build-worker.mjs', {type: 'module'}), declarations);
      const snapshot = {version: 1, projectId: 'A', revision: 0, entry: 'main.lua', files: [
        {path: 'main.lua', kind: 'text', text: 'return 1'}, {path: 'typed.tl', kind: 'text', text: 'local x: number = 1\nreturn x'},
        {path: 'broken.lua', kind: 'text', text: 'local ='},
      ]};
      const backend = createWorkerBuildBackend(snapshot, {compile() {throw new Error('Unexpected TS dispatch');}}, {sessionId:'test', declarations:[], compilerVersion:'test', compileNonTs});
      const workflow = {};
      const built = await createBuildHandler(backend)({workingDir:'A', workflow, cancellation:{isCancelled:()=>false}}, {paths:['main.lua','typed.tl','broken.lua']});
      const derived = await compileTealProject({version:1, projectId:'A', revision:8, entry:'main.tl', files:[
        {path:'main.tl',kind:'text',text:'local dep = require("dep")\nreturn dep'},
        {path:'dep.tl',kind:'text',text:'return 42'},
      ]}, compileNonTs);
      return { good: await run('return 1'), bad: await run('return "wrong"'), recovered: await run('return 2'), ticks, built, workflow, derived };
    }
    finally { clearInterval(timer); }
  }, declarations);
  assert.equal(result.good.checked?.success, true, JSON.stringify(result.good));
  assert.equal(result.built.output.succeededBuildCount, 2, JSON.stringify(result.built));
  assert.equal(result.built.output.failedBuildCount, 1);
  assert.match(result.built.output.results[2].messages[0].message, /line 1/);
  assert.equal(result.workflow.buildRepairPending, true);
  assert.equal(result.derived.success, true, JSON.stringify(result.derived));
  assert.equal(result.derived.snapshot.entry, 'main.lua');
  assert.deepEqual(result.derived.snapshot.files.map(file => file.path), ['main.lua','dep.lua']);
  assert.match(result.derived.snapshot.files[1].text, /42/);
  assert.equal(result.good.compiled.success, true);
  assert.equal(result.good.compiled.revision, 7);
  assert.equal(result.good.lua.success, true);
  assert.equal(result.good.luaInvalid.success, false);
  assert.equal(result.good.luaInvalid.diagnostics[0].type, 'syntax');
  assert.equal(result.good.luaInvalid.diagnostics[0].path, 'broken.lua');
  assert.equal(result.good.luaFiltered.success, true);
  assert.equal(result.good.foreignRejected, true);
  assert.equal(result.good.disposedRejected, true);
  assert.equal(result.bad.checked.success, false);
  assert.equal(result.bad.compiled.success, false);
  assert.equal(result.recovered.checked.success, true);
  assert.ok(result.ticks > 0);
  assert.deepEqual(errors, []);
  console.log(`PASS Chrome ${browser.version()}: Teal Wasm Worker dependencies, diagnostics, generation, immutable snapshot and lifecycle; ${result.ticks} page heartbeats`);
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
