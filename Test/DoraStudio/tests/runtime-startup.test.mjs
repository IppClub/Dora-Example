import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const loader = await readFile(new URL('../../Projects/Web/web-loader.js', import.meta.url), 'utf8');
test('startup waits for a snapshot and never releases main after invalid input', async () => {
  let deliver, aborted;
  const snapshot = new Promise(resolve => { deliver = resolve; });
  const done = new Promise(resolve => { aborted = resolve; });
  const dependencies = [], released = [], states = [];
  const context = vm.createContext({
    Module: { doraSnapshot: snapshot }, document: {},
    window: { doraSetState: state => states.push(state) },
    location: { search: '', href: 'https://runtime.example/' }, URLSearchParams,
    FS: { mkdir() {}, mkdirTree() {}, mount() {}, syncfs(_populate, callback) { callback(); } },
    IDBFS: {}, addRunDependency: name => dependencies.push(name),
    removeRunDependency: name => released.push(name), abort: message => aborted(message),
    fetch() { throw new Error('Must not download the default manifest'); },
  });
  vm.runInContext(loader, context);
  context.Module.preRun[0]();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(dependencies, ['dora-web-manifest']);
  assert.deepEqual(released, []);
  assert.deepEqual(states, []);
  deliver(null);
  assert.match(await done, /invalid runtime snapshot/);
  assert.deepEqual(states, ['faulted']);
  assert.deepEqual(released, [], 'Failed resources must not unblock engine main');
});
