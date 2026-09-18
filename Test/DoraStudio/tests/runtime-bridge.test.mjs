import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { createHash } from 'node:crypto';
import { serializeArtifactContent } from '../packages/contracts/dist/index.js';
const result = await build({ entryPoints: [new URL('../apps/web/src/runtime-bridge.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm', target: 'es2022' });
const { installRuntimeBridge } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
function setup(options = {}) {
  const listeners = new Map(), timers = new Map();
  const page = { parent: {}, setTimeout(fn) { timers.set(1, fn); return 1; }, clearTimeout(id) { timers.delete(id); },
    addEventListener(type, fn) { listeners.set(type, fn); }, removeEventListener(type) { listeners.delete(type); } };
  const module = { print() {}, printErr() {} }, messages = [];
  const port = { postMessage(event) { messages.push(event); }, start() {}, close() { this.closed = true; } };
  const identity = { version: 1, sessionId: 's', projectId: 'p', revision: 1, requestId: 'q', runId: 'r' };
  const bridge = installRuntimeBridge(page, module, { parentOrigin: 'https://studio.example', nonce: 'secret', identity, engineBuild: 'engine', ...options });
  const event = { source: page.parent, origin: 'https://studio.example', data: { type: 'dora-runtime-connect', nonce: 'secret' }, ports: [port] };
  return { page, module, messages, port, bridge, event, listeners, timers, identity };
}
async function mounted(options={}) {
  const s=setup(options);s.listeners.get('message')(s.event);
  const artifact={projectId:'p',revision:1,buildId:'b',compilerVersion:'test',entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}],sourceMaps:{}};
  artifact.sha256=createHash('sha256').update(serializeArtifactContent(artifact)).digest('hex');
  await s.port.onmessage({data:{...s.identity,type:'loadSnapshot',engineBuild:'engine',profile:'dora-preset',artifact}});
  s.listeners.get('dora-statechange')({detail:{state:'running'}});
  return s;
}
test('capture bridge reports unsupported runtimes and ignores foreign requests',async()=>{
  const s=await mounted();
  await s.port.onmessage({data:{...s.identity,type:'captureGame',captureId:'one',runId:'foreign'}});
  assert.equal(s.messages.some(m=>m.type==='captureFailed'),false);
  await s.port.onmessage({data:{...s.identity,type:'captureGame',captureId:'one'}});
  assert.match(s.messages.at(-1).message,/不支持/);s.bridge.dispose();
});
test('capture bridge validates output, prevents overlap/replay and suppresses results after disposal',async()=>{
  let finish,signal,calls=0;
  const s=await mounted({captureGame:input=>{signal=input;calls++;return new Promise(resolve=>{finish=resolve;});}});
  const send=id=>s.port.onmessage({data:{...s.identity,type:'captureGame',captureId:id}});
  const pending=send('one');await send('one');await send('two');
  assert.equal(calls,1);assert.match(s.messages.at(-1).message,/正在处理/);
  finish({png:new Uint8Array(0),width:1,height:1});await pending;
  assert.match(s.messages.at(-1).message,/无效/);
  await send('one');assert.equal(calls,1);
  const late=send('three');s.bridge.dispose();
  assert.equal(signal.aborted,true);assert.equal(s.timers.size,0);
  const count=s.messages.length;finish({png:new Uint8Array(0),width:1,height:1});await late;
  assert.equal(s.messages.length,count);
});
test('runtime bridge binds exact parent, origin and nonce, then closes on disposal', async () => {
  const s = setup(), connect = s.listeners.get('message');
  for (const patch of [{ source: {} }, { origin: 'https://evil.example' }, { data: { type: 'dora-runtime-connect', nonce: 'wrong' } }, { ports: [] }]) {
    connect({ ...s.event, ...patch });
    assert.equal(s.messages.length, 0);
  }
  connect(s.event);
  assert.equal(s.messages[0].state, 'loading');
  assert.equal(s.listeners.has('message'), false);
  connect(s.event);
  assert.equal(s.messages.length, 1);
  s.bridge.dispose();
  await assert.rejects(s.module.doraSnapshot, /disposed/);
  assert.equal(s.port.closed, true);
  assert.equal(s.listeners.size, 0);
  assert.equal(s.timers.size, 0);
});
test('runtime bridge timeout rejects the pending snapshot and ignores late connections', async () => {
  const s = setup(), connect = s.listeners.get('message');
  s.timers.get(1)();
  await assert.rejects(s.module.doraSnapshot, /disposed/);
  connect(s.event);
  assert.equal(s.messages.length, 0);
  assert.equal(s.listeners.size, 0);
});

test('runtime logs carry identity, truncate long lines and bound bursts', () => {
  const s = setup(); s.listeners.get('message')(s.event);
  s.module.print('x'.repeat(9000));
  const log = s.messages.at(-1);
  assert.equal(log.message.length, 8192);
  assert.equal(log.runId, s.identity.runId);
  for (let i = 0; i < 500; i++) s.module.print('line');
  assert.equal(s.messages.filter(event => event.type === 'log').length, 201);
  assert.equal(s.messages.at(-1).level, 'warning');
  s.bridge.dispose();
  const count = s.messages.length;
  s.module.print('late');
  assert.equal(s.messages.length, count);
});

test('runtime bridge ignores stale identities and mounts exactly one valid snapshot', async () => {
  const s = setup(); s.listeners.get('message')(s.event);
  const artifact = { projectId: 'p', revision: 1, buildId: 'b', compilerVersion: 'test', entry: 'init.lua',
    files: [{ path: 'init.lua', kind: 'text', text: 'print(1)' }], sourceMaps: {} };
  artifact.sha256 = createHash('sha256').update(serializeArtifactContent(artifact)).digest('hex');
  const command = { ...s.identity, type: 'loadSnapshot', engineBuild: 'engine', profile: 'dora-preset', artifact };
  for (const patch of [{ runId: 'old' }, { revision: 0 }, { sessionId: 'old' }, { requestId: 'old' }]) {
    await s.port.onmessage({ data: { ...command, ...patch } });
    assert.equal(s.timers.size, 1);
  }
  await s.port.onmessage({ data: command });
  const mounted = await s.module.doraSnapshot;
  assert.equal(new TextDecoder().decode(mounted.files[0].bytes), 'print(1)');
  assert.equal(s.timers.size, 0);
  await s.port.onmessage({ data: { ...command, artifact: null } });
  assert.equal(await s.module.doraSnapshot, mounted);
  s.bridge.dispose();
});
