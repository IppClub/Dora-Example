// Experimental real-engine startup probe. A passing startup is not an isolation gate.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const runtime = resolve(process.env.STUDIO_RUNTIME_DIR || '../build/studio-main-worker');
const testContextLoss = process.env.STUDIO_TEST_CONTEXT_LOSS === '1';
const testSnapshot = process.env.STUDIO_TEST_SNAPSHOT === '1';
const output = resolve(`apps/web/artifacts/${testSnapshot ? 'runtime-worker-snapshot' : testContextLoss ? 'runtime-worker-gpu' : 'runtime-worker'}`);
let snapshotScript;
if (testSnapshot) {
  const manifest = JSON.parse(await readFile(resolve(runtime, 'dora-web-manifest.json')));
  const files = await Promise.all(manifest.files.map(async file => {
    const assetPath = resolve(runtime, file.url);
    assert.ok(assetPath.startsWith(runtime + sep));
    return { path: file.path, bytes: [...await readFile(assetPath)] };
  }));
  // Deliver bytes through Module before startup, exercising the actual Wasm FS.
  // This fixture is not the production RuntimeHost message channel.
  snapshotScript = `doraSnapshot: Promise.resolve(${JSON.stringify({ manifest, files })}).then(s => ({...s, files:s.files.map(f => ({...f, bytes:new Uint8Array(f.bytes)}))})),`;
}
const report = { runtime, errors: [], logs: [], missing: [], requests: [], workers: [], ready: false };
const server = createServer(async (req, res) => {
  report.requests.push(req.url);
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cache-Control', 'no-store');
  if (req.url === '/favicon.ico') { res.writeHead(204); res.end(); return; }
  try {
    const path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const file = resolve(runtime, '.' + (path === '/' ? '/dora-player-runtime.html' : path));
    if (!file.startsWith(runtime + sep)) throw new Error('outside runtime');
    let bytes = await readFile(file);
    if (testSnapshot && file.endsWith('/dora-player-runtime.html')) {
      const html = bytes.toString();
      assert.match(html, /var Module\s*=\s*\{/);
      bytes = Buffer.from(html.replace(/var Module\s*=\s*\{/, () => `var Module = {${snapshotScript}`));
    }
    res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json' })[extname(file)] || 'application/octet-stream');
    res.end(bytes);
  } catch { report.missing.push(req.url); res.writeHead(404); res.end(); }
});
await mkdir(output, { recursive: true });
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  const features = JSON.parse(await readFile(resolve(runtime, 'dora-web-features.json')));
  assert.equal(features.modules.threads, true);
  report.features = features;
  report.wasmSha256 = createHash('sha256').update(await readFile(resolve(runtime, 'dora-player-runtime.wasm'))).digest('hex');
  browser = await chromium.launch({ headless: true,
    args: ['--no-proxy-server', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'],
    ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}),
  });
  report.browser = browser.version();
  const page = await browser.newPage();
  page.on('pageerror', error => report.errors.push(error.stack || error.message));
  page.on('console', message => {
    report.logs.push({ type: message.type(), text: message.text() });
    // Native logger forwards severity inside console.log, not console.error.
    if (message.type() === 'error' || /\[error\]/i.test(message.text())) report.errors.push(message.text());
  });
  page.on('worker', worker => report.workers.push(worker.url()));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  await page.waitForFunction(() => document.documentElement.dataset.doraState === 'running', null, { timeout: 20000 });
  report.ready = true;
  const deadline = Date.now() + 20000;
  while (!report.logs.some(log => log.text.includes('Dora SSR Web Player manifest game ready'))) {
    if (report.errors.length || Date.now() > deadline) break;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  await page.screenshot({ path: resolve(output, 'startup.png') });
  report.workerState = await Promise.all(page.workers().map(worker => worker.evaluate(() => ({
    manifest: Boolean(globalThis.Module?.doraManifest),
    loader: typeof globalThis.DoraWebLoader?.fetchPath,
    moduleFS: typeof globalThis.Module?.FS,
  })).catch(error => ({ error: String(error) }))));
  report.pageState = await page.evaluate(() => ({
    manifest: Boolean(globalThis.Module?.doraManifest),
    loader: typeof globalThis.DoraWebLoader?.fetchPath,
    moduleFS: typeof globalThis.Module?.FS,
  }));
  assert.equal(report.errors.length, 0, 'Runtime entered running but emitted engine errors');
  assert.ok(report.logs.some(log => log.text.includes('Dora SSR Web Player manifest game ready')),
    'Runtime entered running but the manifest fixture did not complete');
  report.readback = await page.evaluate(() => {
    const bytes = Module.FS.readFile('/tmp/dora-web-render-target.png');
    return { size: bytes.length, signature: [...bytes.slice(0, 8)] };
  });
  assert.ok(report.readback.size > 8);
  assert.deepEqual(report.readback.signature, [137, 80, 78, 71, 13, 10, 26, 10]);
  if (testSnapshot) {
    report.snapshot = { mounted: true, projectRequests: report.requests.filter(url =>
      url.startsWith('/assets/') || url.includes('dora-web-manifest.json')) };
    assert.deepEqual(report.snapshot.projectRequests, [], 'Memory snapshots must not fetch game files');
  }
  if (testContextLoss) {
    let renderWorker;
    for (const worker of page.workers()) {
      if (await worker.evaluate(() => typeof GL !== 'undefined' && Boolean(GL.currentContext?.GLctx))) renderWorker = worker;
    }
    assert.ok(renderWorker, 'Must locate the actual Worker WebGL context');
    await page.keyboard.down('ArrowRight');
    assert.equal(await page.evaluate(() => DoraWebPlatform.state.pressedKeys), 1);
    report.gpu = { lossRequested: await renderWorker.evaluate(() => {
      const context = GL.currentContext.GLctx;
      const extension = context.getExtension('WEBGL_lose_context');
      if (!extension) return false;
      context.canvas.addEventListener('webglcontextlost', () => { globalThis.studioContextLost = true; });
      extension.loseContext();
      return true;
    }) };
    assert.ok(report.gpu.lossRequested);
    const lossDeadline = Date.now() + 5000;
    do {
      report.gpu.lost = await renderWorker.evaluate(() => globalThis.studioContextLost === true);
      if (report.gpu.lost) break;
      await new Promise(resolve => setTimeout(resolve, 50));
    } while (Date.now() < lossDeadline);
    assert.ok(report.gpu.lost, 'Must observe actual context loss, not just request it');
    await page.waitForFunction(() => document.documentElement.dataset.doraState === 'faulted', null, { timeout: 5000 });
    report.gpu.stateAfterLoss = await page.evaluate(() => document.documentElement.dataset.doraState);
    await page.waitForFunction(() => DoraWebPlatform.state.audioState !== 'running');
    report.gpu.platformAfterLoss = await page.evaluate(async () => {
      await DoraWebPlatform.unlockAudio();
      await DoraWebPlatform.setSuspended(false);
      return DoraWebPlatform.state;
    });
    assert.equal(report.gpu.platformAfterLoss.active, false);
    assert.equal(report.gpu.platformAfterLoss.pressedKeys, 0);
    assert.equal(report.gpu.platformAfterLoss.activePointers, 0);
    assert.notEqual(report.gpu.platformAfterLoss.audioState, 'running');
    report.gpu.frameAfterResumeAttempt = await renderWorker.evaluate(() =>
      Module.ccall('dora_web_set_suspended', 'number', ['number'], [0]));
    await new Promise(resolve => setTimeout(resolve, 300));
    report.gpu.frameAfterWait = await renderWorker.evaluate(() =>
      Module.ccall('dora_web_set_suspended', 'number', ['number'], [0]));
    assert.equal(report.gpu.frameAfterWait, report.gpu.frameAfterResumeAttempt,
      'A faulted renderer must not resume advancing frames');
    await page.close();
    const recovered = await browser.newPage();
    const recoveryLogs = [], recoveryErrors = [];
    recovered.on('pageerror', error => recoveryErrors.push(error.message));
    recovered.on('console', message => {
      recoveryLogs.push(message.text());
      if (message.type() === 'error' || /\[error\]/i.test(message.text())) recoveryErrors.push(message.text());
    });
    await recovered.goto(`http://127.0.0.1:${server.address().port}/`);
    const recoveryDeadline = Date.now() + 20000;
    while (!recoveryLogs.some(log => log.includes('Dora SSR Web Player manifest game ready')) &&
      !recoveryErrors.length && Date.now() < recoveryDeadline) await new Promise(resolve => setTimeout(resolve, 50));
    report.gpu.recoveryErrors = recoveryErrors;
    report.gpu.restarted = recoveryLogs.some(log => log.includes('Dora SSR Web Player manifest game ready'));
    assert.equal(recoveryErrors.length, 0);
    assert.ok(report.gpu.restarted, 'Fresh runtime must complete the real manifest fixture');
    await recovered.screenshot({ path: resolve(output, 'recovered.png') });
  }
} catch (error) {
  report.failure = String(error);
  process.exitCode = 1;
} finally {
  await browser?.close();
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  await writeFile(resolve(output, 'startup.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
}
