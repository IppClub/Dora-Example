import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {isBuildArtifact} from '../packages/contracts/dist/index.js';

const bundled=await build({entryPoints:[new URL('../apps/web/src/workspace-runtime-artifact.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm',target:'es2022'});
const {resolveWorkspaceRuntimeArtifact}=await import(`data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`);
const snapshot=(files,entry='main.ts')=>({version:1,projectId:'p',revision:3,entry,files});
const source={path:'main.ts',kind:'text',text:'export const value=1;'};

test('workspace runtime prefers Agent-generated Lua without requiring a Studio build',async()=>{
  const result=await resolveWorkspaceRuntimeArtifact(snapshot([source,{path:'main.lua',kind:'text',text:'print("agent")'}]),null);
  assert.equal(result.entry,'main.lua');
  assert.equal(result.compilerVersion,'dora-studio-workspace-1');
  assert.equal(isBuildArtifact(result),true);
});

test('workspace runtime keeps an explicit build when generated output is absent',async()=>{
  const compiled={buildId:'b',projectId:'p',revision:3,compilerVersion:'compiler',entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'print("compiled")'}],sourceMaps:{},sha256:'a'.repeat(64)};
  assert.equal(await resolveWorkspaceRuntimeArtifact(snapshot([source]),compiled),compiled);
  const stale={...compiled,revision:2};
  const current=await resolveWorkspaceRuntimeArtifact(snapshot([source]),stale);
  assert.notEqual(current,stale);
  assert.equal(current.revision,3);
  assert.equal(current.entry,'main.ts');
});

test('workspace runtime packages raw source and leaves missing compilation diagnosis to Player',async()=>{
  const result=await resolveWorkspaceRuntimeArtifact(snapshot([source]),null);
  assert.equal(result.entry,'main.ts');
  assert.equal(isBuildArtifact(result),true);
});
