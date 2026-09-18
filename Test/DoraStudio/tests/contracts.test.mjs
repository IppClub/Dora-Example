import test from 'node:test';
import assert from 'node:assert/strict';
import { authoredProjectFiles, generatedLuaPathForSource, generatedLuaSourcePath, isGeneratedLuaFile, validateSnapshot, isProjectPath, matchesRequest, matchesCompileResult, matchesRuntimeEvent, cancelsRequest, isCorrelation, isBuildArtifact, isRuntimeCommand, isRuntimeEvent } from '../packages/contracts/dist/index.js';

test('same-basename Lua output is recognized only when an authored source variant exists',()=>{
  const files=[{path:'main.ts'},{path:'main.lua'},{path:'native.lua'},{path:'nested/view.yue'},{path:'nested/view.lua'},{path:'image.png'}];
  assert.equal(generatedLuaSourcePath('main.lua',files),'main.ts');
  assert.equal(isGeneratedLuaFile('nested/view.lua',files),true);
  assert.equal(isGeneratedLuaFile('native.lua',files),false);
  assert.deepEqual(authoredProjectFiles(files).map(file=>file.path),['main.ts','native.lua','nested/view.yue','image.png']);
  assert.equal(generatedLuaPathForSource('main.ts'),'main.lua');
  assert.equal(generatedLuaPathForSource('nested/View.YUE'),'nested/View.lua');
  assert.equal(generatedLuaPathForSource('native.lua'),undefined);
  assert.equal(generatedLuaPathForSource('image.png'),undefined);
});
import {validateProjectArchive} from '../packages/contracts/dist/index.js';
test('non-executable archives share file safety but never pass executable snapshot validation',()=>{
 const archive={version:1,kind:'project-archive',projectId:'archive',revision:0,entry:null,files:[{path:'init.wasm',kind:'binary',bytes:new Uint8Array([0,97,115,109])}]};
 const before=structuredClone(archive);assert.deepEqual(validateProjectArchive(archive),[]);assert.ok(validateSnapshot(archive).length);assert.deepEqual(archive,before);
 for(const patch of [{entry:'init.wasm'},{kind:'project'},{revision:-1},{files:[]},{files:[{path:'../escape',kind:'binary',bytes:new Uint8Array()}]},{files:[...archive.files,...archive.files]},{files:[...archive.files,{path:'init.wasm/child',kind:'text',text:''}]}])assert.ok(validateProjectArchive({...archive,...patch}).length);
 const disguised={...archive,entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'print(1)'}]};assert.ok(validateSnapshot(disguised).length);assert.ok(validateProjectArchive(disguised).length);
 assert.equal(isBuildArtifact({...archive,buildId:'b',compilerVersion:'c',sha256:'a'.repeat(64),sourceMaps:{}}),false);
});

const snapshot = () => ({ version: 1, projectId: 'p1', revision: 0, entry: 'init.lua', files: [
  { path: 'init.lua', kind: 'text', text: 'print("hello")' },
  { path: 'Images/icon.png', kind: 'binary', bytes: new Uint8Array([0, 255]) },
] });
const identity = { version: 1, projectId: 'p1', sessionId: 's1', revision: 0, requestId: 'q1' };
const artifact = () => ({ ...snapshot(), buildId: 'b1', compilerVersion: 'compiler1', sourceMaps: {}, sha256: 'a'.repeat(64) });

test('wire runtime commands validate identity and snapshot ownership before dispatch', () => {
  const command = { ...identity, runId: 'run1', type: 'loadSnapshot', artifact: artifact(), engineBuild: 'engine1', profile: 'default' };
  assert.equal(isRuntimeCommand(structuredClone(command)), true);
  for (const type of ['start', 'stop', 'restart', 'suspend', 'releaseInput']) {
    assert.equal(isRuntimeCommand({ ...identity, runId: 'run1', type }), true);
  }
  for (const patch of [{ type: 'execute' }, { runId: '' }, { engineBuild: '' }, { profile: null },
    { artifact: null }, { artifact: { ...artifact(), projectId: 'other' } },
    { artifact: { ...artifact(), revision: 1 } }]) {
    assert.equal(isRuntimeCommand({ ...command, ...patch }), false);
  }
  for (const invalid of [null, [], true, 1, 'command', {}, { ...identity, revision: NaN },
    { ...identity, revision: -1 }, { ...identity, version: 2 }, { ...identity, requestId: ' ' }]) {
    assert.equal(isCorrelation(invalid), false);
    assert.equal(isRuntimeCommand(invalid), false);
    assert.equal(isRuntimeEvent(invalid), false);
  }
});

test('artifact wire validation checks hash shape, paths, entry and source maps', () => {
  assert.equal(isBuildArtifact(artifact()), true);
  assert.equal(isBuildArtifact({ ...artifact(), sourceMaps: { 'init.lua.map': '{}' } }), true);
  for (const patch of [{ sha256: 'test' }, { files: [] }, { entry: '../init.lua' },
    { sourceMaps: [] }, { sourceMaps: { '../x': '{}' } }, { sourceMaps: { 'init.lua.map': 1 } },
    { sourceMaps: { 'init.lua': '{}' } }, { sourceMaps: { 'Images/icon.png.map': '{}' } }]) {
    assert.equal(isBuildArtifact({ ...artifact(), ...patch }), false);
  }
});

test('runtime wire events reject unknown states, levels, error codes and nonfinite timing', () => {
  const base = { ...identity, runId: 'run1' };
  for (const state of ['loading', 'ready', 'running', 'suspended', 'stopped']) {
    assert.equal(isRuntimeEvent({ ...base, type: 'state', state }), true);
  }
  for (const event of [{ type: 'log', level: 'info', message: '' },
    { type: 'error', code: 'runtimeFailure', message: 'failed' }, { type: 'performance', frameMs: 0 }]) {
    assert.equal(isRuntimeEvent({ ...base, ...event }), true);
  }
  for (const event of [{ type: 'state', state: 'crashed' }, { type: 'log', level: 'debug', message: '' },
    { type: 'log', level: 'info', message: 1 }, { type: 'error', code: 'unknown', message: '' },
    ...[-1, NaN, Infinity, '16'].map(frameMs => ({ type: 'performance', frameMs }))]) {
    assert.equal(isRuntimeEvent({ ...base, ...event }), false);
  }
});

test('text/binary snapshots survive structured cloning', () => {
  assert.deepEqual(validateSnapshot(structuredClone(snapshot())), []);
});

test('reject traversal, absolute paths, platform escapes and empty components', () => {
  for (const path of ['', '/init.lua', '../init.lua', 'a/../b', './a', 'a//b', 'C:/x', 'a\\b', 'a\0b', 'a/']) {
    assert.equal(isProjectPath(path), false, path);
  }
  assert.equal(isProjectPath('游戏/入口.lua'), true);
});

test('reject incompatible version, invalid revision, missing entry and malformed content', () => {
  for (const patch of [{ version: 2 }, { revision: -1 }, { revision: 0.5 }, { revision: Number.MAX_SAFE_INTEGER + 1 },
    { projectId: '' }, { entry: 'missing.lua' }, { files: null },
    { files: [{ path: 'init.lua', kind: 'text', text: 2 }] }]) {
    assert.ok(validateSnapshot({ ...snapshot(), ...patch }).length, JSON.stringify(patch));
  }
  assert.ok(validateSnapshot(null).length);
});

test('reject duplicate and file-directory collisions in either order', () => {
  const data = snapshot();
  data.files.push(data.files[0]);
  assert.ok(validateSnapshot(data).some(e => e.includes('duplicate')));
  for (const paths of [['a', 'a/b/c'], ['a/b/c', 'a']]) {
    const data = snapshot();
    data.files.push(...paths.map(path => ({ path, kind: 'text', text: '' })));
    assert.ok(validateSnapshot(data).some(e => e.includes('collision')));
  }
});

test('late replies cannot cross session, project, revision, request or protocol boundaries', () => {
  assert.equal(matchesRequest(identity, { ...identity }), true);
  for (const field of Object.keys(identity)) {
    assert.equal(matchesRequest(identity, { ...identity, [field]: 'other' }), false, field);
  }
});

test('compiled artifacts match their build and compiler; cancellation remains correlated', () => {
  const request = { ...identity, type: 'compile', buildId: 'b1', compilerVersion: '5.9.3', snapshot: snapshot(), declarations: [], options: {} };
  const result = { ...identity, type: 'compiled', buildId: 'b1', diagnostics: [], artifact: {
    buildId: 'b1', projectId: 'p1', revision: 0, compilerVersion: '5.9.3', entry: 'init.lua', files: [], sourceMaps: {}, sha256: 'test',
  } };
  assert.equal(matchesCompileResult(request, result), true);
  for (const field of ['buildId', 'projectId', 'revision', 'compilerVersion']) {
    assert.equal(matchesCompileResult(request, { ...result, artifact: { ...result.artifact, [field]: 'other' } }), false);
  }
  assert.equal(matchesCompileResult(request, { ...identity, type: 'cancelled', buildId: 'b1' }), true);
  assert.equal(matchesCompileResult(request, { ...identity, type: 'cancelled', buildId: 'old' }), false);
});

test('runtime restart isolates previous run events and cancellation targets the original request', () => {
  const command = { ...identity, type: 'start', runId: 'run2' };
  const event = { ...identity, type: 'state', state: 'running', runId: 'run2' };
  assert.equal(matchesRuntimeEvent(command, event), true);
  assert.equal(matchesRuntimeEvent(command, { ...event, runId: 'run1' }), false);
  const cancel = { ...identity, requestId: 'cancel1', type: 'cancel', targetRequestId: 'q1' };
  assert.equal(cancelsRequest(cancel, command), true);
  assert.equal(cancelsRequest(cancel, { ...command, requestId: 'q2' }), false);
  assert.equal(cancelsRequest(cancel, { ...command, sessionId: 'reopened' }), false);
});
