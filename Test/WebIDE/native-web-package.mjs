import assert from 'node:assert/strict';
import {createHash, webcrypto} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {engineVersion} from '../BuildScripts/engine_version.mjs';

// Native GamePackage writes the manifest and delivery scripts. This fixture
// exercises the browser templates with that wire format without starting Dora.
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const entry = Buffer.from('return true');
const image = Buffer.from([0, 255, 20]);
const runtimeWasm = Buffer.from([0, 97, 115, 109]);
const runtimeData = Buffer.from([42]);
const mixerWasm = Buffer.from([0, 97, 115, 109, 1]);
const audioWorklet = Buffer.from('worklet');
const project = {'init.lua': entry, 'Image/中文 #1.png': image};
const files = Object.entries(project).map(([path, bytes]) => ({
  path,
  url: `assets/${digest(bytes)}/${path.split('/').map(encodeURIComponent).join('/')}`,
  size: bytes.length,
  sha256: digest(bytes),
  startup: true,
}));
const manifest = {
  format: 'dora-web-game', version: 1, engineVersion,
  profile: 'dora-preset', entry: 'init.lua', files,
};
const shell = await readFile('public/export-player/index.html', 'utf8');
assert.equal(shell.split('@DORA_GODOT@').length, 2);
assert.equal(shell.split('@DORA_LOADER@').length, 2);
assert.match(shell, /src="dora-logo\.png"/);
const httpLoader = vm.createContext({URL});
vm.runInContext(await readFile('../../Projects/Web/web-loader.js', 'utf8'), httpLoader);
httpLoader.DoraWebLoader.validateManifest(manifest, 'https://example.test/game/dora-web-manifest.json');

// A standalone export starts at file:// and receives the native package's
// embedded WASM, preload data, audio, and snapshot through script delivery.
const scripts = new Map();
const records = {};
const resources = {
  'dora-player-runtime.wasm': runtimeWasm,
  'dora-player-runtime.data': runtimeData,
  'dora-audio-mixer.wasm': mixerWasm,
  'audio-worklet.js': audioWorklet,
  ...Object.fromEntries(files.map(file => [decodeURIComponent(file.url), project[file.path]])),
};
for (const [name, bytes] of Object.entries(resources)) {
  const script = `html-assets/${scripts.size}.js`;
  records[name] = {script, size: bytes.length, sha256: digest(bytes)};
  scripts.set(script, `DoraHtmlPackage.deliver(${JSON.stringify(name)}, ${JSON.stringify(bytes.toString('base64'))});`);
}
const loader = await readFile('public/export-player/html-loader.js', 'utf8');
assert.equal(loader.split('DORA_EXPORT_CONFIG').length, 2);
const source = loader.replace('DORA_EXPORT_CONFIG', () => JSON.stringify({manifest, records}));

async function bootHtml(overrides = new Map()) {
  const faults = [], requests = [], blobs = [], revoked = [];
  const baseURI = 'file:///test/中文%20game/index.html';
  const root = new URL('.', baseURI).href;
  class LocalURL extends URL {
    static createObjectURL(blob) { blobs.push(blob); return 'blob:test/' + blobs.length; }
    static revokeObjectURL(url) { revoked.push(url); }
  }
  const browser = {
    URL: LocalURL, Blob, TextEncoder, Uint8Array, atob, btoa, crypto: webcrypto, WebAssembly,
    setTimeout, clearTimeout, console: {error() {}, warn() {}}, Module: {},
    doraSetProgress() {},
    doraSetState(state, message) { faults.push({state, message}); },
    addEventListener() {},
    document: {
      baseURI, createElement: () => ({remove() {}}),
      body: {
        appendChild(script) {
          assert.ok(script.src.startsWith(root), script.src);
          const relative = decodeURIComponent(script.src.slice(root.length));
          requests.push(relative);
          if (relative === 'dora-player-runtime.js') {
            if (overrides.has(relative)) script.onerror();
            return;
          }
          const code = overrides.has(relative) ? overrides.get(relative) : scripts.get(relative);
          queueMicrotask(() => {
            if (code === undefined) { script.onerror(); return; }
            vm.runInContext(code, sandbox);
            script.onload();
          });
        },
      },
    },
  };
  browser.window = browser;
  const sandbox = vm.createContext(browser);
  await vm.runInContext(source, sandbox);
  return {module: browser.Module, faults, requests, blobs, revoked};
}

const local = await bootHtml();
assert.deepEqual(local.faults, []);
assert.equal(local.requests.at(-1), 'dora-player-runtime.js');
assert.deepEqual(Buffer.from(local.module.wasmBinary), runtimeWasm);
assert.deepEqual(Buffer.from(local.module.getPreloadedPackage()), runtimeData);
assert.equal(local.module.getPreloadedPackage(), null);
for (const file of local.module.doraSnapshot.files) assert.deepEqual(Buffer.from(file.bytes), project[file.path]);
assert.equal(local.blobs.length, 1);
assert.match(local.module.locateFile('audio-worklet.js'), /^data:text\/javascript;base64,/);
assert.match(local.module.locateFile('dora-audio-mixer.wasm'), /^blob:/);
assert.match(local.module.doraStorageId, /^html-[a-f0-9]{64}$/);
local.module.onRuntimeInitialized();
assert.equal(local.module.doraSnapshot, undefined);

const wasmScript = records['dora-player-runtime.wasm'].script;
const missing = await bootHtml(new Map([[wasmScript, undefined]]));
assert.match(missing.faults[0].message, /Extract the entire ZIP/);
assert.ok(!missing.requests.includes('dora-player-runtime.js'));
const corrupt = await bootHtml(new Map([[wasmScript, 'DoraHtmlPackage.deliver("dora-player-runtime.wasm","AAAAAA==");']]));
assert.match(corrupt.faults[0].message, /checksum mismatch/);
assert.ok(!corrupt.requests.includes('dora-player-runtime.js'));
const noEngine = await bootHtml(new Map([['dora-player-runtime.js', undefined]]));
assert.match(noEngine.faults[0].message, /Unable to load the engine/);
assert.equal(noEngine.module.doraSnapshot, undefined);
assert.equal(noEngine.module.wasmBinary, undefined);
assert.equal(noEngine.revoked.length, 1);
const aborted = await bootHtml();
aborted.module.onAbort('test abort');
assert.equal(aborted.faults[0].message, 'test abort');
assert.equal(aborted.module.doraSnapshot, undefined);
assert.equal(aborted.module.getPreloadedPackage, undefined);

const noAudio = await bootHtml(new Map([[records['audio-worklet.js'].script, undefined]]));
assert.deepEqual(noAudio.faults, []);
assert.equal(noAudio.module.doraAudioWorklet, false);
assert.equal(noAudio.requests.at(-1), 'dora-player-runtime.js');
console.log('Web game manifest and standalone export loader passed.');
