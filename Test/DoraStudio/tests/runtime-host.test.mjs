import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
const result = await build({ entryPoints: [new URL('../apps/web/src/runtime-host.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm', target: 'es2022' });
const { RuntimeHost } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('host restarts destroy old pages, reject stale events and time out by removal', () => {
  const originals = { window: globalThis.window, document: globalThis.document, MessageChannel: globalThis.MessageChannel };
  const frames = [], channels = [], timers = new Map(), events = [];
  let timerId = 0;
  globalThis.window = { location: { href: 'https://studio.example/', origin: 'https://studio.example' },
    setTimeout(fn) { timers.set(++timerId, fn); return timerId; }, clearTimeout(id) { timers.delete(id); } };
  globalThis.document = { createElement() {
    return { setAttribute() {}, remove() { this.removed = true; }, contentWindow: { postMessage() {} } };
  } };
  globalThis.MessageChannel = class {
    constructor() {
      const port = () => ({ start() {}, close() { this.closed = true; }, postMessage(data) { this.sent = data; } });
      this.port1 = port(); this.port2 = port(); channels.push(this);
    }
  };
  try {
    const artifact = { projectId: 'p', revision: 1, buildId: 'b', compilerVersion: 'test', entry: 'init.lua',
      files: [{ path: 'init.lua', kind: 'text', text: '' }], sourceMaps: {}, sha256: 'a'.repeat(64) };
    const host = new RuntimeHost({ append(frame) { frames.push(frame); } },
      { runtimeURL: 'https://runtime.example/player.html', engineBuild: 'engine', onEvent: event => events.push(event) });
    host.start(artifact); frames[0].onload();
    const first = channels[0].port1.sent, oldMessage = channels[0].port1.onmessage;
    const event = { ...first, type: 'state', state: 'running' };
    oldMessage({ data: { ...event, runId: 'foreign' } });
    assert.equal(events.length, 0);
    oldMessage({ data: event });
    assert.equal(events.length, 1);
    assert.equal(timers.size, 0);
    host.start(artifact); frames[1].onload();
    assert.equal(frames[0].removed, true);
    assert.equal(channels[0].port1.closed, true);
    oldMessage({ data: event });
    assert.equal(events.length, 1);
    assert.notEqual(channels[1].port1.sent.runId, first.runId);
    [...timers.values()][0]();
    assert.equal(frames[1].removed, true);
    assert.equal(events.at(-1).code, 'timeout');
    host.stop();
    const sameOrigin = new RuntimeHost({ append() {} },
      { runtimeURL: '/player.html', engineBuild: 'engine', onEvent() {} });
    assert.throws(() => sameOrigin.start(artifact), /独立来源/);
  } finally {
    for (const [key, value] of Object.entries(originals)) {
      if (value === undefined) delete globalThis[key]; else globalThis[key] = value;
    }
  }
});
