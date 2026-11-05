import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

test('default Godot adapter preserves ordinary offline Dora and requires isolation for Godot content', async () => {
  const script = await readFile(new URL('../../Projects/Web/web-godot.js', import.meta.url), 'utf8');
  let prior = 0;
  const Module = {doraPrepareRuntime: async () => { prior++; }, doraManifest: {files: [{path: 'init.lua'}]}};
  const context = vm.createContext({Module, crossOriginIsolated: false,
    addRunDependency() { throw new Error('Ordinary offline Dora must not wait for Godot'); }});
  vm.runInContext(script, context);
  for (const preRun of Module.preRun) preRun();
  await Module.doraPrepareRuntime();
  assert.equal(prior, 1);
  for (const path of ['game/project.godot', 'game.pck']) {
    Module.doraManifest.files = [{path}];
    await assert.rejects(Module.doraPrepareRuntime(), /COOP\/COEP/);
  }
});
