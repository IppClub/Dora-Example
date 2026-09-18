import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { resolve, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const runtime = resolve(process.env.STUDIO_RUNTIME_DIR || fileURLToPath(new URL('../../build/web-demo-profile/', import.meta.url)));
const threaded = process.env.STUDIO_RUNTIME_THREADS === '1';
const browserLabel = process.env.STUDIO_BROWSER_LABEL || '';
assert.ok(/^[a-z0-9-]*$/.test(browserLabel), 'Browser evidence label must be a safe directory suffix');
const output = fileURLToPath(new URL(`../apps/web/artifacts/${threaded ? 'runtime-worker-isolation' : 'runtime-isolation'}${browserLabel ? '-' + browserLabel : ''}/`, import.meta.url));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const names = ['dora-player-runtime.html', 'dora-player-runtime.js', 'dora-player-runtime.wasm', 'dora-player-runtime.data', 'dora-web-features.json', 'dora-audio-mixer.wasm', 'audio-worklet.js'];
const assets = new Map(await Promise.all(names.map(async name => [name, await readFile(resolve(runtime, name))])));
const features = JSON.parse(assets.get('dora-web-features.json'));
assert.equal(features.modules.threads, threaded, 'Runtime must match the requested thread mode');
const fixture = loop => Buffer.from(`local _ENV = Dora
local marker = DrawNode()
marker:drawPolygon({Vec2(-180,-90),Vec2(180,-90),Vec2(180,90),Vec2(-180,90)}, Color(0xff4cc38a))
Director.ui:addChild(marker)
local elapsed = 0
local announced = false
Director.postScheduler:schedule(function(dt)
  elapsed = elapsed + dt
  if elapsed > 1 and not announced then
    announced = true
    print("studio-probe-${loop ? 'loop-start' : 'normal-ready'}")
    ${loop ? 'return false' : 'return true'}
  end
  ${loop ? 'if elapsed > 1.7 then while true do end end' : ''}
  return false
end)
`);
const heartbeat = new Map(), childHeartbeat = new Map(), markers = new Map(), missing = new Set();
const server = createServer((req, res) => {
  const u = new URL(req.url, 'http://localhost'), id = u.searchParams.get('case') || '';
  res.setHeader('cache-control', 'no-store');
  if (threaded) {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  }
  if (u.pathname === '/heartbeat') { heartbeat.set(id, [...(heartbeat.get(id) || []), Date.now()]); res.end(); return; }
  if (u.pathname === '/child-heartbeat') { childHeartbeat.set(id, [...(childHeartbeat.get(id) || []), Date.now()]); res.end(); return; }
  if (u.pathname === '/marker') { markers.set(`${id}:${u.searchParams.get('kind')}`, Date.now()); res.end(); return; }
  if (u.pathname === '/parent') {
    const childHost = u.searchParams.get('cross') === '1' ? 'runtime.localhost' : 'studio.localhost';
    res.setHeader('content-type', 'text/html');
    res.end(`<!doctype html><title>Studio isolation probe</title><p id="status">Parent responsive</p><iframe id="game" width="640" height="480" sandbox="allow-scripts allow-same-origin"></iframe><script>
      const id=${JSON.stringify(id)};
      setInterval(()=>{document.querySelector('#status').textContent=String(Date.now());navigator.sendBeacon('/heartbeat?case='+id)},50);
      const origin='http://${childHost}:'+location.port;
      window.mount=(loop)=>{document.querySelector('#game')?.remove();const f=document.createElement('iframe');f.id='game';f.width=640;f.height=480;f.sandbox='allow-scripts allow-same-origin';f.src=origin+'/player?case='+id+'&loop='+Number(loop);document.body.appendChild(f)};
      mount(false);
    </script>`); return;
  }
  if (u.pathname === '/player') {
    const bridge = `<script>setInterval(()=>navigator.sendBeacon('/child-heartbeat?case=${encodeURIComponent(id)}'),50);Module.doraManifestUrl='/manifest?case=${encodeURIComponent(id)}&loop=${u.searchParams.get('loop')}';Module.doraStorageId='studio-probe-${id}';Module.print=(...a)=>{console.log(...a);const text=a.join(' ');for(const kind of ['loop-start','normal-ready'])if(text.includes('studio-probe-'+kind))navigator.sendBeacon('/marker?case=${encodeURIComponent(id)}&kind='+kind)};</script>`;
    res.setHeader('content-type', 'text/html');
    res.end(assets.get('dora-player-runtime.html').toString().replace('<script async src=', bridge + '<script async src=')); return;
  }
  if (u.pathname === '/manifest') {
    const source = fixture(u.searchParams.get('loop') === '1');
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({ format: 'dora-web-game', version: 1, engineVersion: '1.9.2', profile: features.activeProfile,
      entry: 'init.lua', files: [{ path: 'init.lua', url: `/fixture.lua?loop=${u.searchParams.get('loop')}`, size: source.length, sha256: digest(source), startup: true }] })); return;
  }
  if (u.pathname === '/fixture.lua') { res.end(fixture(u.searchParams.get('loop') === '1')); return; }
  const file = u.pathname.slice(1);
  if (assets.has(file)) {
    res.setHeader('content-type', ({ '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json' })[extname(file)] || 'application/octet-stream');
    res.end(assets.get(file)); return;
  }
  if (u.pathname === '/favicon.ico') { res.writeHead(204); res.end(); return; }
  missing.add(u.pathname); res.writeHead(404); res.end();
});
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(test, ms, label) {
  const deadline = Date.now() + ms;
  while (!test()) { if (Date.now() > deadline) throw new Error(`Timed out: ${label}`); await pause(50); }
}
async function bounded(promise, ms) {
  let timer;
  try { return await Promise.race([promise, new Promise(resolve => { timer = setTimeout(() => resolve({ timeout: true }), ms); })]); }
  finally { clearTimeout(timer); }
}
await mkdir(output, { recursive: true });
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const reports = [];
try {
  for (const crossSite of threaded ? [false] : [false, true]) {
    const id = crossSite ? 'cross-site' : 'same-origin';
    const browser = await chromium.launch({ headless: true,
      args: ['--no-proxy-server', '--host-resolver-rules=MAP studio.localhost 127.0.0.1, MAP runtime.localhost 127.0.0.1', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'],
      ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}),
    });
    const report = { mode: id, threaded, browser: browser.version(), errors: [] };
    try {
      const page = await browser.newPage();
      page.on('pageerror', error => report.errors.push(error.message));
      page.on('console', message => {
        const text = message.text();
        if (message.type() === 'error') report.errors.push(text);
        // Browser network dispatch can itself be starved by the loop. CDP console
        // delivery is observed outside the page and doesn't require its event loop.
        for (const kind of ['loop-start', 'normal-ready']) if (text.includes(`studio-probe-${kind}`)) markers.set(`${id}:${kind}`, Date.now());
      });
      await page.goto(`http://studio.localhost:${server.address().port}/parent?case=${id}&cross=${Number(crossSite)}`);
      await until(() => markers.has(`${id}:normal-ready`), 20000, `${id} normal rendering: ${JSON.stringify(report.errors)}`);
      await page.screenshot({ path: resolve(output, `${id}-normal.png`) });
      const normalFrame = page.frames().find(frame => frame.url().includes('/player?'));
      if (threaded) {
        report.normalWorkers = await Promise.all(page.workers().map(worker =>
          bounded(worker.evaluate(() => 42).then(value => ({ responsive: value === 42 })), 1000)));
        assert.ok(report.normalWorkers.length > 0 && report.normalWorkers.every(worker => worker.responsive),
          'normal runtime workers must respond before the loop test');
      }
      await normalFrame.evaluate(() => window.doraStop());
      await normalFrame.waitForFunction(() => document.documentElement.dataset.doraState === 'stopped');
      report.normalStop = true;
      const cdp = await browser.newBrowserCDPSession();
      report.frameTargets = (await cdp.send('Target.getTargets')).targetInfos.filter(t => t.type === 'iframe').map(t => t.url);
      await page.evaluate(() => mount(true));
      await until(() => markers.has(`${id}:loop-start`), 20000, `${id} Lua loop start`);
      await pause(1200);
      const count = heartbeat.get(id)?.length ?? 0;
      const childCount = childHeartbeat.get(id)?.length ?? 0;
      await pause(1000);
      report.heartbeatsDuringLoop = (heartbeat.get(id)?.length ?? 0) - count;
      report.childHeartbeatsDuringLoop = (childHeartbeat.get(id)?.length ?? 0) - childCount;
      if (threaded) {
        report.loopWorkers = await Promise.all(page.workers().map(worker =>
          bounded(worker.evaluate(() => 42).then(value => ({ responsive: value === 42 }))
            .catch(error => ({ error: error.message })), 1000)));
      }
      const removal = await bounded(page.evaluate(() => { document.querySelector('#game').remove(); return { removed: true }; }).catch(error => ({ error: error.message })), 1500);
      report.removal = removal;
      if (removal.removed) {
        if (threaded) {
          await until(() => page.workers().length === 0, 3000, 'old workers destroyed');
          report.oldWorkersDestroyed = true;
        }
        markers.delete(`${id}:normal-ready`);
        await page.evaluate(() => mount(false));
        try {
          await until(() => markers.has(`${id}:normal-ready`), 15000, `${id} restart`);
          report.restarted = true;
        } catch (error) { report.restarted = false; report.restartFailure = String(error); }
      } else report.restarted = false;
      report.satisfiesRecoveryGate = report.heartbeatsDuringLoop > 0 &&
        (threaded ? report.childHeartbeatsDuringLoop > 0 && report.loopWorkers.some(worker => worker.timeout) &&
          report.oldWorkersDestroyed : report.childHeartbeatsDuringLoop === 0) && report.restarted;
      report.missingResources = [...missing];
      console.log(JSON.stringify(report));
      reports.push(report);
    } catch (error) {
      await writeFile(resolve(output, `${id}-failure.json`), JSON.stringify({ ...report, failure: String(error) }, null, 2));
      throw error;
    } finally { await browser.close(); }
  }
  const evidence = { observedAt: new Date().toISOString(), runtime, featureProfile: features,
    assets: Object.fromEntries([...assets].map(([name, bytes]) => [name, { size: bytes.length, sha256: digest(bytes) }])), missingResources: [...missing], reports };
  await writeFile(resolve(output, 'report.json'), JSON.stringify(evidence, null, 2));
  assert.ok(reports.every(r => r.normalStop), 'both topologies must first prove actual Dora startup and stop');
  console.log(`Evidence written to ${output}; recovery gates: ${reports.map(r => `${r.mode}=${r.satisfiesRecoveryGate}`).join(', ')}. This probe does not establish cross-browser runtime isolation.`);
} finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
