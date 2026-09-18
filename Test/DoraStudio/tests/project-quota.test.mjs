import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openProjectStore} from '../apps/server/project-store.mjs';
test('project quota counts immutable history, preserves retry receipts and isolates account usage',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-project-quota-')),path=join(dir,'db');
 const options={maxProjects:1,maxVersions:2,maxBytes:4096},store=openProjectStore(path,options),peer=openProjectStore(path,options);
 const snapshot={version:1,projectId:'game',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'-- 中文'}]},first={requestId:'one',baseRevision:0,name:'Game',snapshot};
 try{
  store.save('a',first);const initial=store.usage('a');assert.equal(initial.projects,1);assert.equal(initial.versions,1);
  assert.equal(initial.bytes,Buffer.byteLength(JSON.stringify(snapshot)));
  assert.throws(()=>peer.save('a',{...first,requestId:'second-project',snapshot:{...snapshot,projectId:'other'}}),/quota exceeded/);
  peer.save('a',{...first,requestId:'two',baseRevision:1});
  assert.throws(()=>store.save('a',{...first,requestId:'three',baseRevision:2}),/quota exceeded/);
  assert.equal(store.usage('a').versions,2);assert.equal(store.get('a','game').cloudRevision,2);
  assert.deepEqual(peer.save('a',first),{cloudRevision:1,replayed:true});
  assert.equal(peer.usage('a').bytes,initial.bytes*2);
  assert.equal(store.usage('b').bytes,0);store.save('b',first);
  const strict=openProjectStore(path,{...options,maxBytes:initial.bytes});
  try{assert.throws(()=>strict.save('b',{...first,requestId:'two',baseRevision:1}),/quota exceeded/);assert.equal(strict.get('b','game').cloudRevision,1);}finally{strict.close();}
  assert.deepEqual(peer.save('b',{...first,requestId:'two',baseRevision:1}),{cloudRevision:2,replayed:false});
  assert.throws(()=>openProjectStore(path,{maxVersions:0}),/Invalid project quota/);
 }finally{peer.close();store.close();rmSync(dir,{recursive:true,force:true});}
});
