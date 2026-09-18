import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';

const bundle=await build({
  stdin:{contents:`export {isLiveWorkspaceAgent} from './workspace-agent';`,resolveDir:resolve('apps/web/src'),loader:'ts'},
  bundle:true,write:false,format:'cjs',platform:'node',treeShaking:true,
});
const mod={exports:{}};
new Function('module','exports','require',bundle.outputFiles[0].text)(mod,mod.exports,createRequire(import.meta.url));
const {isLiveWorkspaceAgent}=mod.exports;

test('a closed Agent binding is never reused for another prompt or project sync',()=>{
  const binding={projectId:'project-a',controller:{closed:false}};
  assert.equal(isLiveWorkspaceAgent(binding,'project-a'),true);
  binding.controller.closed=true;
  assert.equal(isLiveWorkspaceAgent(binding,'project-a'),false);
  binding.controller.closed=false;
  assert.equal(isLiveWorkspaceAgent(binding,'project-b'),false);
  assert.equal(isLiveWorkspaceAgent(undefined,'project-a'),false);
});
