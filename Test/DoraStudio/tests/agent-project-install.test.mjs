import test from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {build} from 'esbuild';
const bundle=await build({stdin:{contents:"export * from './apps/web/src/agent-project-install';export * from './apps/web/src/agent-project-baseline';",resolveDir:process.cwd(),loader:'ts'},bundle:true,write:false,format:'esm',platform:'node'});
const {readInstalledAgentFiles:readFiles,installAgentProjectSnapshot:install,matchesInstalledAgentProject:matches,readAgentProjectBaseline:readBaseline,writeAgentProjectBaseline:writeBaseline}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const input={version:1,projectId:'p',revision:2,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'-- 中文'},{path:'Resources/a.bin',kind:'binary',bytes:new Uint8Array([0,255,128])}]};
test('current file capture owns exact bytes, excludes session data and reflects deletes',()=>{
 const f=fixture();try{
  install(f.api,input);
  const captured=readFiles(f.api);
  assert.deepEqual(captured.map(f=>f.path),['Resources/a.bin','init.lua']);
  assert.deepEqual([...captured[0].bytes],[0,255,128]);
  captured[0].bytes[0]=99;
  assert.equal(f.api.readFile('/user/studio-project/Resources/a.bin')[0],0);
  f.api.unlink('/user/studio-project/init.lua');
  assert.deepEqual(readFiles(f.api).map(f=>f.path),['Resources/a.bin']);
 }finally{f.close();}
});
test('current file capture rejects links and validates sizes before reading',()=>{
 const f=fixture();try{
  install(f.api,input);
  let reads=0;
  assert.throws(()=>readFiles({...f.api,lstat:p=>p.endsWith('a.bin')?{mode:0o100644,size:64*1024*1024+1}:f.api.lstat(p),readFile:p=>{reads++;return f.api.readFile(p);}}),/bounds/);
  assert.equal(reads,0);
  assert.throws(()=>readFiles({...f.api,readFile:()=>new Uint8Array()}),/changed/);
  fs.symlinkSync(f.path('/game'),f.path('/user/studio-project/link'));
  assert.throws(()=>readFiles(f.api),/links/);
 }finally{f.close();}
});
test('persisted baseline reconstructs only verified files and retains a revision floor on divergence',async()=>{
 const f=fixture(),signal=new AbortController().signal;try{
  assert.equal(await readBaseline(f.api,'p',signal),undefined);
  install(f.api,input);await writeBaseline(f.api,input,signal);
  assert.deepEqual(await readBaseline(f.api,'p',signal),{revision:2,snapshot:input});
  f.api.writeFile('/user/studio-project/init.lua',Buffer.from('unreconciled'));
  assert.deepEqual(await readBaseline(f.api,'p',signal),{revision:2});
  await assert.rejects(readBaseline(f.api,'foreign',signal));
  f.api.writeFile('/user/.studio-author-baseline.json',Buffer.from('{broken'));
  await assert.rejects(readBaseline(f.api,'p',signal));
 }finally{f.close();}
});
function fixture(){
 const base=fs.mkdtempSync(join(tmpdir(),'studio-install-'));
 const path=p=>join(base,p);
 const api={analyzePath:p=>({exists:fs.existsSync(path(p))}),lstat:p=>fs.lstatSync(path(p)),isDir:m=>(m&0o170000)===0o040000,isFile:m=>(m&0o170000)===0o100000,readdir:p=>fs.readdirSync(path(p)),readFile:p=>fs.readFileSync(path(p)),writeFile:(p,b)=>fs.writeFileSync(path(p),b),mkdirTree:p=>fs.mkdirSync(path(p),{recursive:true}),rename:(a,b)=>fs.renameSync(path(a),path(b)),unlink:p=>fs.unlinkSync(path(p)),rmdir:p=>fs.rmdirSync(path(p))};
 api.mkdirTree('/user/studio-project/.agent');api.writeFile('/user/studio-project/.agent/session.json',Buffer.from('keep'));
 api.writeFile('/user/studio-project/old.lua',Buffer.from('old'));api.mkdirTree('/game');api.writeFile('/game/init.lua',Buffer.from('trusted'));
 return {api,path,close:()=>fs.rmSync(base,{recursive:true,force:true})};
}
test('installation replaces author files but preserves Agent state and trusted host',()=>{
 const f=fixture();try{
  assert.deepEqual(install(f.api,input),{projectId:'p',revision:2,cleanupPending:false});
  assert.equal(f.api.readFile('/user/studio-project/.agent/session.json').toString(),'keep');
  assert.equal(f.api.readFile('/game/init.lua').toString(),'trusted');
  assert.equal(f.api.analyzePath('/user/studio-project/old.lua').exists,false);
  assert.deepEqual([...f.api.readFile('/user/studio-project/Resources/a.bin')],[0,255,128]);
  assert.deepEqual(f.api.readdir('/user'),['studio-project']);
 }finally{f.close();}
});
test('installed equality ignores session metadata but rejects author edits, extra files and links',()=>{
 const f=fixture();try{
  install(f.api,input);assert.equal(matches(f.api,input),true);
  f.api.writeFile('/user/studio-project/.agent/new.txt',Buffer.from('metadata'));assert.equal(matches(f.api,input),true);
  f.api.writeFile('/user/studio-project/init.lua',Buffer.from('changed'));assert.equal(matches(f.api,input),false);
  install(f.api,input);f.api.writeFile('/user/studio-project/extra.txt',Buffer.from('extra'));assert.equal(matches(f.api,input),false);
  install(f.api,input);f.api.unlink('/user/studio-project/init.lua');assert.equal(matches(f.api,input),false);
  fs.symlinkSync(f.path('/game/init.lua'),f.path('/user/studio-project/init.lua'));assert.equal(matches(f.api,input),false);
 }finally{f.close();}
});
test('write and exchange failures retain the prior project',()=>{
 for(const mode of ['write','exchange']){
  const f=fixture();try{
   const api={...f.api};
   if(mode==='write')api.writeFile=(p,b)=>{if(p.endsWith('/init.lua'))throw Error('quota');f.api.writeFile(p,b);};
   else api.rename=(a,b)=>{if(a.includes('.studio-author-stage-')&&b==='/user/studio-project')throw Error('exchange');f.api.rename(a,b);};
   assert.throws(()=>install(api,input));
   assert.equal(f.api.readFile('/user/studio-project/old.lua').toString(),'old');
   assert.equal(f.api.readFile('/user/studio-project/.agent/session.json').toString(),'keep');
   assert.deepEqual(f.api.readdir('/user'),['studio-project']);
  }finally{f.close();}
 }
});
test('session-data conflicts and symlinks fail without modifying the old root',()=>{
 const f=fixture();try{
  assert.throws(()=>install(f.api,{...input,files:[...input.files,{path:'.agent/stolen',kind:'text',text:'x'}]}),/conflicts/);
  fs.symlinkSync(f.path('/game'),f.path('/user/studio-project/.agent/link'));
  assert.throws(()=>install(f.api,input),/links/);
  assert.equal(f.api.readFile('/user/studio-project/old.lua').toString(),'old');
 }finally{f.close();}
});
test('post-commit cleanup failure reports a committed project with recovery data retained',()=>{
 const f=fixture();try{
  const api={...f.api,unlink:p=>{if(p.includes('.studio-author-backup-'))throw Error('cleanup');f.api.unlink(p);}};
  assert.equal(install(api,input).cleanupPending,true);
  assert.equal(f.api.readFile('/user/studio-project/init.lua').toString(),'-- 中文');
  assert.ok(f.api.readdir('/user').some(name=>name.startsWith('.studio-author-backup-')));
 }finally{f.close();}
});
