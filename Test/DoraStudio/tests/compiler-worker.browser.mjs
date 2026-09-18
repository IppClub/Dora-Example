import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { build } from 'esbuild';
const agentBundle = (await build({ stdin: { contents: `export { createWorkerBuildBackend } from './worker-build.js';
export { createBuildHandler, validateBuild } from './build-tool.js';
export { getToolDefinition } from './index.js';
export { executeAgentToolDefinition } from './executor.js';`, resolveDir: new URL('../packages/agent-contracts/dist/', import.meta.url).pathname },
  bundle: true, format: 'esm', platform: 'browser', write: false })).outputFiles[0].text;
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const declarations = await Promise.all(['Dora.d.ts', 'es6-subset.d.ts', 'lua.d.ts', 'jsx.d.ts'].map(async path => ({
  path, kind: 'text', text: await readFile(new URL(`../../Assets/Script/Lib/Dora/en/${path}`, import.meta.url), 'utf8'),
})));
declarations.push({ path: 'lualib_bundle.lua', kind: 'text', text: await readFile(new URL('../../Assets/Script/Lib/lualib_bundle.lua', import.meta.url), 'utf8') });
const requests = [];
const allowed = new Set(['/client.js', '/worker.js', '/typescript.js', '/compile-worker.js', '/agent-build.js']);
const server = createServer(async (req, res) => {
  requests.push(req.url);
  if (req.url === '/') { res.setHeader('content-type', 'text/html'); res.end('<!doctype html><title>Studio Worker verification</title>'); return; }
  if (req.url === '/agent-build.js') { res.setHeader('content-type', 'text/javascript'); res.end(agentBundle); return; }
  if (allowed.has(req.url)) {
    try {
      const bytes = await readFile(new URL(`../packages/compiler-web/dist/browser${req.url}`, import.meta.url));
      res.setHeader('content-type', 'text/javascript'); res.end(bytes); return;
    } catch {}
  }
  res.writeHead(404); res.end();
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const results = await page.evaluate(async declarations => {
    const { CompilerClient } = await import('/client.js');
    const { createWorkerBuildBackend, createBuildHandler, validateBuild, getToolDefinition, executeAgentToolDefinition } = await import('/agent-build.js');
    let cancelWhenStarted = false, startedCancellation = false, onCompileStarted;
    let workerCount = 0, terminatedCount = 0;
    const client = new CompilerClient(() => {
      const worker = new Worker(new URL('/worker.js', location.href));
      workerCount++;
      const terminate = worker.terminate.bind(worker);
      worker.terminate = () => { terminatedCount++; terminate(); };
      worker.addEventListener('message', event => {
        if (event.data.type === 'compileStarted' && onCompileStarted) {
          const callback = onCompileStarted; onCompileStarted = undefined; callback();
        }
        if (cancelWhenStarted && event.data.type === 'compileStarted') {
          startedCancellation = true; cancelWhenStarted = false; client.cancel();
        }
      });
      return worker;
    });
    let id = 0, ticks = 0;
    const timer = setInterval(() => ticks++, 5);
    const make = (text, entry = 'main.ts', timeoutMs = 15000) => ({
      version: 1, type: 'compile', sessionId: 'browser', projectId: 'game', revision: ++id,
      requestId: String(id), buildId: String(id), compilerVersion: 'dora-tstl-0.1.0-ts5.9.3', options: {}, timeoutMs, declarations,
      snapshot: { version: 1, projectId: 'game', revision: id, entry, files: [
        { path: entry, kind: 'text', text }, { path: 'logic/value.ts', kind: 'text', text: 'export const answer = 42;' },
        { path: 'images/test.bin', kind: 'binary', bytes: new Uint8Array([0, 1, 255]) },
      ] },
    });
    try {
      const text = 'import { Vec2 } from "Dora"; import { answer } from "logic/value"; export const p = Vec2(answer, 1); export const values = [1, 2].map(x => x + 1);';
      const before = ticks;
      const good = await client.compile(make(text)); const compileTicks = ticks - before;
      const warningText='export function normalize(value: number) { if (value) return 1; return 0; }';
      const warning=await client.compile(make(warningText));
      const agentWarningSnapshot=make(warningText).snapshot;
      const agentWarningOptions={sessionId:'agent-warning',compilerVersion:'dora-tstl-0.1.0-ts5.9.3',declarations};
      const agentWarning=await createWorkerBuildBackend(agentWarningSnapshot,client,agentWarningOptions)({workDir:'game',path:'main.ts'});
      const agentWarningWorkflow={unbuiltEdits:true,editsSinceBuild:1,freshProjectBuildPending:true};
      const agentWarningContext={role:'main',workMode:'code',taskId:9,workingDir:'game',workflow:agentWarningWorkflow,disabledAgentTools:[],cancellation:{isCancelled:()=>false,reason:()=>undefined}};
      const agentWarningDefinition={...getToolDefinition('build'),validateInput:validateBuild,
        handler:createBuildHandler(async()=>structuredClone(agentWarning))};
      const agentWarningTool=await executeAgentToolDefinition(agentWarningDefinition,{paths:['main.ts']},agentWarningContext,{searchDoraDocLimitMax:20});
      const bad = await client.compile(make('export const x: number = "bad";'));
      const cancelledPromise = client.compile(make(text)); client.cancel(); const cancelled = await cancelledPromise;
      cancelWhenStarted = true;
      const activeCancelled = await client.compile(make(Array.from({ length: 10000 }, (_, i) => `export const v${i} = ${i};`).join('\n')));
      const timeout = await client.compile(make(text, 'main.ts', 1));
      const recovered = await client.compile(make(text));
      const lua = await client.compile(make('return 42', 'main.lua'));
      const collisionRequest = make(text);
      collisionRequest.snapshot.files.push({ path: 'main.lua', kind: 'text', text: 'return 1' });
      const siblingRebuild = await client.compile(collisionRequest);
      const targetedRequest = make(text);
      targetedRequest.snapshot.files.push({ path: 'unrelated.ts', kind: 'text', text: 'export const broken: number = "bad";' });
      const wholeProject = await client.compile(targetedRequest);
      targetedRequest.rootNames = ['main.ts'];
      const targeted = await client.compile(targetedRequest);
      targetedRequest.snapshot.files.find(f => f.path === 'logic/value.ts').text = 'export const answer: number = "bad";';
      const importedError = await client.compile(targetedRequest);
      const invalidRoots = [];
      for (const rootNames of [[], ['../main.ts'], ['missing.ts'], ['main.ts', 'main.ts'], ['logic/value.ts']]) {
        invalidRoots.push(await client.compile({ ...targetedRequest, rootNames }));
      }
      const agentSnapshot = make(text).snapshot;
      const agentOptions = { sessionId: 'agent-task', compilerVersion: 'dora-tstl-0.1.0-ts5.9.3', declarations };
      const agentGood = await createWorkerBuildBackend(agentSnapshot, client, agentOptions)({ workDir: 'game', path: 'main.ts' });
      agentSnapshot.files[0].text = 'export const x: number = "bad";';
      const agentBad = await createWorkerBuildBackend(agentSnapshot, client, agentOptions)({ workDir: 'game', path: 'main.ts' });
      const stopped = new AbortController(); stopped.abort();
      const agentCancelled = await createWorkerBuildBackend(agentSnapshot, client, { ...agentOptions, signal: stopped.signal })({ workDir: 'game', path: 'main.ts' });
      const workflow = { unbuiltEdits: true, editsSinceBuild: 1, freshProjectBuildPending: true };
      const context = { role: 'main', workMode: 'code', taskId: 1, workingDir: 'game', workflow,
        disabledAgentTools: [], cancellation: { isCancelled: () => false, reason: () => undefined } };
      const definition = { ...getToolDefinition('build'), validateInput: validateBuild,
        handler: createBuildHandler(createWorkerBuildBackend(agentSnapshot, client, agentOptions)) };
      const execute = (input, ctx = context) => executeAgentToolDefinition(definition, input, ctx, { searchDoraDocLimitMax: 20 });
      const invalidToolBuild = await execute({ paths: [] });
      const disabledToolBuild = await execute({ path: '.' }, { ...context, disabledAgentTools: ['build'] });
      const toolBuild = await execute({ paths: ['main.ts', 'logic/value.ts'] });
      const failedWorkflow = structuredClone(workflow);
      const toolRecovery = await execute({ path: 'logic/value.ts' });
      const cancellationRuns = [];
      for (const mode of ['signal', 'predicate']) {
        const controller = new AbortController();
        let predicate = false, started = false;
        onCompileStarted = () => { started = true; if (mode === 'signal') controller.abort(); else predicate = true; };
        const beforeWorkers = workerCount, beforeTerminated = terminatedCount;
        const snapshot = make(Array.from({ length: 10000 }, (_, i) => `export const v${i} = ${i};`).join('\n')).snapshot;
        const backend = createWorkerBuildBackend(snapshot, client, { ...agentOptions, signal: controller.signal });
        const result = await backend({ workDir: 'game', path: '.', isCancelled: () => predicate });
        cancellationRuns.push({ mode, started, result, workers: workerCount - beforeWorkers, terminated: terminatedCount - beforeTerminated });
      }
      const afterTaskCancel = await createWorkerBuildBackend(make(text).snapshot, client, agentOptions)({ workDir: 'game', path: 'main.ts' });
      return { good, warning, agentWarning, agentWarningTool, agentWarningWorkflow, bad, cancelled, activeCancelled, startedCancellation, timeout, recovered, lua, siblingRebuild, compileTicks,
        wholeProject, targeted, importedError, invalidRoots, agentGood, agentBad, agentCancelled,
        invalidToolBuild, disabledToolBuild, toolBuild, failedWorkflow, toolRecovery, workflow, cancellationRuns, afterTaskCancel };
    } finally { clearInterval(timer); client.dispose(); }
  }, declarations);
  assert.equal(results.good.type, 'compiled', JSON.stringify(results.good));
  assert.equal(results.warning.type,'compiled',JSON.stringify(results.warning));
  assert.ok(results.warning.diagnostics.some(d=>d.code==='100037'&&d.severity==='warning'));
  assert.equal(results.agentWarning.success,false,JSON.stringify(results.agentWarning));
  assert.match(results.agentWarning.messages[0].message,/main\.ts\(1,48\): warning TS100037/);
  assert.equal(results.agentWarningTool.output.success,false,JSON.stringify(results.agentWarningTool));
  assert.equal(results.agentWarningWorkflow.buildRepairPending,true);
  assert.match(results.good.artifact.files.find(f => f.path === 'main.lua').text, /logic.value/);
  assert.ok(results.good.artifact.files.some(f => f.path === 'logic/value.lua'));
  assert.ok(results.good.artifact.sourceMaps['main.lua.map']);
  assert.deepEqual(Object.values(results.good.artifact.files.find(f => f.path === 'images/test.bin').bytes), [0, 1, 255]);
  assert.equal(results.bad.type, 'compileFailed');
  assert.equal(results.agentGood.success, true, JSON.stringify(results.agentGood));
  assert.equal(results.agentGood.messages[0].file, 'main.ts');
  assert.equal(results.agentBad.success, false);
  assert.match(results.agentBad.messages[0].message, /2322/);
  assert.equal(results.agentCancelled.interrupted, true);
  for (const run of results.cancellationRuns) {
    assert.equal(run.started, true, run.mode);
    assert.equal(run.result.interrupted, true, JSON.stringify(run));
    assert.equal(run.workers, 1, JSON.stringify(run));
    assert.equal(run.terminated, 1, JSON.stringify(run));
  }
  assert.equal(results.afterTaskCancel.success, true, JSON.stringify(results.afterTaskCancel));
  assert.equal(results.invalidToolBuild.output.code, 'INVALID_TOOL_INPUT');
  assert.equal(results.disabledToolBuild.output.code, 'TOOL_DISABLED');
  assert.equal(results.toolBuild.output.partial, true, JSON.stringify(results.toolBuild));
  assert.equal(results.toolBuild.output.failedBuildCount, 1);
  assert.equal(results.toolBuild.output.succeededBuildCount, 1);
  assert.equal(results.failedWorkflow.buildRepairPending, true);
  assert.equal(results.failedWorkflow.freshProjectBuildPending, true);
  assert.equal(results.toolRecovery.output.success, true, JSON.stringify(results.toolRecovery));
  assert.equal(results.workflow.buildRepairPending, false);
  assert.equal(results.workflow.freshProjectBuildPending, false);
  assert.equal(results.wholeProject.type, 'compileFailed');
  assert.equal(results.targeted.type, 'compiled', JSON.stringify(results.targeted));
  assert.ok(results.targeted.artifact.files.some(f => f.path === 'logic/value.lua'));
  assert.ok(!results.targeted.artifact.files.some(f => f.path === 'unrelated.lua'));
  assert.equal(results.importedError.type, 'compileFailed');
  assert.ok(results.importedError.diagnostics.some(d => d.path === 'logic/value.ts'));
  assert.ok(results.invalidRoots.every(result => result.type === 'requestFailed'));
  assert.ok(results.bad.diagnostics.some(d => d.code === '2322' && d.path === 'main.ts' && typeof d.start === 'number'));
  assert.equal(results.cancelled.type, 'cancelled'); assert.equal(results.timeout.code, 'timeout');
  assert.equal(results.activeCancelled.type, 'cancelled'); assert.equal(results.startedCancellation, true);
  assert.equal(results.siblingRebuild.type, 'compiled');
  assert.match(results.siblingRebuild.artifact.files.find(f=>f.path==='main.lua').text,/logic.value/);
  assert.equal(results.recovered.type, 'compiled', JSON.stringify(results.recovered));
  assert.equal(results.good.artifact.sha256, results.recovered.artifact.sha256);
  assert.equal(results.lua.type, 'compiled'); assert.equal(results.lua.artifact.entry, 'main.lua');
  assert.ok(results.compileTicks > 3, `main-thread heartbeat: ${results.compileTicks}`);
  assert.deepEqual(errors, []);
  assert.deepEqual(requests.filter(url => url !== '/' && url !== '/favicon.ico' && !allowed.has(url)), []);
  console.log(`PASS Chrome ${browser.version()}: real Worker TS/Lua, diagnostics, binary assets, hash, cancellation, timeout and recovery; ${results.compileTicks} main-thread heartbeats during compile; no native services.`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
