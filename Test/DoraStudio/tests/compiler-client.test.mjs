import test from 'node:test';
import assert from 'node:assert/strict';
import { CompilerClient } from '../packages/compiler-web/dist/client.js';

const request = (id = 'a', timeoutMs = 1000) => ({ version: 1, type: 'compile', sessionId: 's', projectId: 'p', revision: 1,
  requestId: id, buildId: id, compilerVersion: 'test', timeoutMs, options: {}, declarations: [],
  snapshot: { version: 1, projectId: 'p', revision: 1, entry: 'main.lua', files: [{ path: 'main.lua', kind: 'text', text: '' }] } });
const response = r => ({ version: 1, sessionId: r.sessionId, projectId: r.projectId, revision: r.revision,
  requestId: r.requestId, buildId: r.buildId, type: 'compileFailed', diagnostics: [] });
function setup() {
  const workers = [];
  const client = new CompilerClient(() => {
    const worker = { onmessage: null, onerror: null, onmessageerror: null, terminated: false,
      postMessage(r) { this.request = r; }, terminate() { this.terminated = true; } };
    workers.push(worker); return worker;
  });
  return { workers, client };
}

test('task abort terminates its compiler and cannot cancel a replacement', async () => {
  const { client, workers } = setup();
  const controller = new AbortController();
  const first = client.compile(request(), controller.signal);
  controller.abort();
  assert.equal((await first).type, 'cancelled');
  assert.equal(workers[0].terminated, true);
  const next = client.compile(request('next'));
  const stale = new AbortController(); stale.abort();
  assert.equal((await client.compile(request('stale'), stale.signal)).type, 'cancelled');
  assert.equal(workers.length, 2);
  assert.equal(workers[1].terminated, false);
  workers[1].onmessage({ data: response(request('next')) });
  assert.equal((await next).type, 'compileFailed');
});

test('a superseded task signal and factory-time abort are safely isolated', async () => {
  const { client, workers } = setup();
  const controller = new AbortController();
  const first = client.compile(request(), controller.signal);
  const second = client.compile(request()); // Intentionally reuse the request ID.
  await first;
  controller.abort();
  assert.equal(workers[1].terminated, false);
  workers[1].onmessage({ data: response(request()) });
  await second;
  const duringStart = new AbortController();
  let terminated = false;
  const racing = new CompilerClient(() => {
    duringStart.abort();
    return { onmessage: null, onerror: null, onmessageerror: null,
      postMessage() { assert.fail('aborted task dispatched'); }, terminate() { terminated = true; } };
  });
  assert.equal((await racing.compile(request(), duringStart.signal)).type, 'cancelled');
  assert.equal(terminated, true);
});

test('new builds terminate old workers and ignore captured late callbacks', async () => {
  const { client, workers } = setup();
  const a = client.compile(request());
  const oldReply = workers[0].onmessage;
  const b = client.compile(request('b'));
  assert.equal((await a).type, 'cancelled');
  assert.equal(workers[0].terminated, true);
  oldReply({ data: response(request()) });
  workers[1].onmessage({ data: response(request('b')) });
  assert.equal((await b).requestId, 'b');
  assert.equal(workers[1].terminated, true);
  client.dispose();
});

test('cancel targets only the active request and identity is copied', async () => {
  const { client, workers } = setup();
  const r = request(); const promise = client.compile(r); r.requestId = 'mutated';
  assert.equal(client.cancel('mutated'), false);
  assert.equal(client.cancel('a'), true);
  assert.equal((await promise).requestId, 'a');
  assert.equal(workers[0].terminated, true);
});

test('foreign and malformed messages cannot finish a build', async () => {
  const { client, workers } = setup(); const promise = client.compile(request());
  for (const data of [null, {}, { ...response(request()), projectId: 'other' },
    { ...response(request()), diagnostics: [null] },
    { ...response(request()), type: 'compiled', artifact: null }]) workers[0].onmessage({ data });
  assert.equal(workers[0].terminated, false);
  workers[0].onmessage({ data: response(request()) });
  assert.equal((await promise).type, 'compileFailed');
});

test('timeout terminates worker and subsequent build recovers', async () => {
  const { client, workers } = setup();
  assert.equal((await client.compile(request('slow', 5))).code, 'timeout');
  assert.equal(workers[0].terminated, true);
  const next = client.compile(request('next')); workers[1].onmessage({ data: response(request('next')) });
  assert.equal((await next).type, 'compileFailed');
});

test('invalid diagnostic spans cannot reach the editor; valid declaration paths survive', async () => {
  const { client, workers } = setup();
  const pending = client.compile(request());
  const diagnostic = { severity: 'error', code: '123', message: 'type error', path: '/dora/Dora.d.ts', start: 0, length: 1 };
  for (const patch of [{ start: -1 }, { start: NaN }, { length: Infinity }, { length: 0.5 },
    { path: {} }, { severity: ['error'] }, { start: Number.MAX_SAFE_INTEGER, length: 1 }]) {
    workers[0].onmessage({ data: { ...response(request()), diagnostics: [{ ...diagnostic, ...patch }] } });
    assert.equal(workers[0].terminated, false);
  }
  workers[0].onmessage({ data: { ...response(request()), diagnostics: [diagnostic] } });
  assert.deepEqual((await pending).diagnostics, [diagnostic]);
  assert.equal(workers[0].terminated, true);
});

test('startup, execution and decoding failures settle and dispose prevents reuse', async () => {
  const failed = new CompilerClient(() => { throw new Error('blocked'); });
  assert.equal((await failed.compile(request())).code, 'internal');
  for (const event of ['onerror', 'onmessageerror']) {
    const { client, workers } = setup(); const promise = client.compile(request());
    workers[0][event]({}); assert.equal((await promise).code, 'internal');
    assert.equal(workers[0].terminated, true); client.dispose();
    await assert.rejects(client.compile(request()), /disposed/);
  }
});
