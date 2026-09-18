import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
test('trusted host support artifact matches its manifest and original Lua bridges',async()=>{
  const root=new URL('../dist/agent-host/',import.meta.url);
  const manifest=JSON.parse(await readFile(new URL('manifest.json',root),'utf8'));
  assert.equal(manifest.kind,'dora-studio-agent-host-support');
  assert.equal(manifest.requires.studioAgentHost,true);
  assert.deepEqual(manifest.files.slice(0,3).map(file=>file.path),['host.js','page.js','index.html']);
  for(const name of ['compiler/worker.js','compiler/typescript.js','compiler/compile-worker.js','declarations/Dora.d.ts','declarations/lualib_bundle.lua','AgentHostSession.lua','AgentSessionBridge.lua','StudioAgentEntry.lua','StudioAgentYueBuild.lua','StudioAgentXmlBuild.lua','lua/Utils.lua'])assert.ok(manifest.files.some(file=>file.path===name));
  assert.equal(manifest.originalAgentLibraries,'included');
  assert.ok(manifest.files.some(file=>file.path==='lua/Agent/Session.lua'));
  assert.ok(manifest.files.some(file=>file.path==='lua/lualib_bundle.lua'));
  assert.ok(manifest.files.some(file=>file.path==='lua/Agent/Tool/Build.lua'));
  for(const file of manifest.files){
    const bytes=await readFile(new URL(file.path,root));
    assert.equal(bytes.length,file.size);assert.equal(createHash('sha256').update(bytes).digest('hex'),file.sha256);
    if(['AgentHostSession.lua','AgentSessionBridge.lua','StudioAgentEntry.lua','StudioAgentYueBuild.lua','StudioAgentXmlBuild.lua'].includes(file.path))assert.deepEqual(bytes,await readFile(new URL('../packages/runtime-web/'+file.path,import.meta.url)));
    if(file.path==='lua/Utils.lua')assert.deepEqual(bytes,await readFile(new URL('../../Assets/Script/Lib/Utils.lua',import.meta.url)));
  }
  const code=await readFile(new URL('host.js',root),'utf8');
  const api=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
  assert.deepEqual(Object.keys(api).sort(),['acquireAgentStorage','agentStorageId','decodeAgentHostConfig','prepareAgentBootstrap','prepareAgentHostRuntime']);
});
