import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorkspaceBuild } from '../packages/agent-contracts/dist/workspace-build.js';

function fixture(files, overrides = {}) {
  const calls = [];
  const Path = (...parts) => parts.join('/');
  Path.getExt = path => path.split('/').at(-1).split('.').slice(1).at(-1) ?? '';
  Path.getName = path => path.split('/').at(-1).replace(/\.[^.]*$/, '');
  const host = {
    Path, Log() {},
    Content: { exist: path => path === 'p' || files.has(path), isdir: path => path === 'p',
      load: path => files.get(path), isAbsolutePath: () => false },
    resolveWorkspaceSearchPath: (workDir, path) => workDir === 'p' && !path.includes('..') ? (path === '.' ? 'p' : `p/${path}`) : undefined,
    toWorkspaceRelativePath: (_workDir, path) => path.slice(2),
    listFiles: () => ({ success: true, files: [...files.keys()].map(path => path.slice(2)) }),
    sendWebIDEFileUpdate: () => true,
    runSingleTsTranspile: async path => { calls.push(path); return { success: true, file: path }; },
    runSingleNonTsBuild: async path => { calls.push(path); return { success: true, file: path }; },
    ...overrides,
  };
  return { build: createWorkspaceBuild(host), calls };
}

test('original workspace build traverses all languages and excludes declarations/tiled TS', async () => {
  const files = new Map(['main.ts', 'types.d.ts', 'tile.ts', 'a.lua', 'a.tl', 'a.yue', 'a.xml', 'a.yarn', 'note.md']
    .map(path => [`p/${path}`, path === 'tile.ts' ? '<?xml version="1.0"?>' : 'source']));
  const { build, calls } = fixture(files);
  const result = await build({ workDir: 'p', path: '.' });
  assert.deepEqual(calls, ['p/main.ts', 'p/a.lua', 'p/a.tl', 'p/a.yue', 'p/a.xml', 'p/a.yarn']);
  assert.equal(result.success, true);
  assert.equal(result.total, 6);
  assert.equal(result.messages[0].file, 'main.ts');
});

test('original workspace build preserves per-file failure, cancellation and missing target errors', async () => {
  let cancelled = false;
  const { build } = fixture(new Map([['p/main.ts', 'source'], ['p/next.lua', 'source']]), {
    runSingleTsTranspile: async file => { cancelled = true; return { success: false, file, message: 'type error' }; },
  });
  const partial = await build({ workDir: 'p', path: '.', isCancelled: () => cancelled });
  assert.equal(partial.interrupted, true);
  assert.equal(partial.messages.length, 1);
  assert.equal(partial.messages[0].message, 'type error');
  cancelled = false;
  const failed = await build({ workDir: 'p', path: 'main.ts' });
  assert.equal(failed.failed, 1);
  assert.equal(Object.hasOwn(failed, 'interrupted'), false);
  assert.equal(failed.messages[0].file, 'main.ts');
  assert.equal((await build({ workDir: 'other', path: '.' })).message, 'invalid path or workDir');
  assert.equal((await build({ workDir: 'p', path: 'missing.ts' })).message, 'path not existed');
});
