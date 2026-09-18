import test from 'node:test';
import assert from 'node:assert/strict';
import {cp,mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createAgentHostSnapshot as assemble} from '../scripts/agent-host-snapshot.mjs';
const config={version:1,parentOrigin:'https://studio.example',accountId:'a',projectId:'p',generation:'g',projectRoot:'/user/studio-project',title:'中文 "); error("not code")'};
test('host snapshot keeps configuration as data and includes the trusted original library',async()=>{
  const snapshot=await assemble(config,{engineVersion:'1.9.2'});
  assert.ok(snapshot.files.some(file=>file.path==='Agent/Session.lua'));
  assert.ok(snapshot.files.some(file=>file.path==='Script/Lib/Dora/en/Dora.d.ts'));
  assert.ok(snapshot.files.some(file=>file.path==='Script/Lib/Dora/zh-Hans/Dora.d.ts'));
  assert.ok(snapshot.files.some(file=>file.path.startsWith('Doc/en/Tutorial/')&&file.path.endsWith('.md')));
  assert.ok(snapshot.files.some(file=>file.path.startsWith('Doc/zh-Hans/Tutorial/')&&file.path.endsWith('.md')));
  assert.ok(!snapshot.files.find(file=>file.path==='init.lua').bytes.toString().includes(config.title));
  assert.equal(JSON.parse(snapshot.files.find(file=>file.path==='studio-host.json').bytes).title,config.title);
  assert.equal(JSON.parse(snapshot.files.find(file=>file.path==='studio-host.json').bytes).projectRoot,'/user/studio-project');
  for(const projectRoot of ['/game','/other','/user/studio-project/../game'])await assert.rejects(assemble({...config,projectRoot},{engineVersion:'1.9.2'}));
});
test('host snapshot rejects tampered or missing library inputs',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'studio-host-snapshot-'));
  try {
    await cp('dist/agent-host',directory,{recursive:true});
    const path=join(directory,'manifest.json'),manifest=JSON.parse(await readFile(path,'utf8'));
    const entry=manifest.files.find(file=>file.path==='lua/Agent/Session.lua'),original=entry.sha256;
    entry.sha256='0'.repeat(64);await writeFile(path,JSON.stringify(manifest));
    await assert.rejects(assemble(config,{engineVersion:'1.9.2',supportDirectory:directory}),/integrity/);
    entry.sha256=original;manifest.files=manifest.files.filter(file=>file!==entry);await writeFile(path,JSON.stringify(manifest));
    await assert.rejects(assemble(config,{engineVersion:'1.9.2',supportDirectory:directory}),/Missing/);
  }finally{await rm(directory,{recursive:true,force:true});}
});
