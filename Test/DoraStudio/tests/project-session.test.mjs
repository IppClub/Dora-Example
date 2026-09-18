import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openProjectStore} from '../apps/server/project-store.mjs';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
test('project save transaction rechecks session owner and account state before writes or receipt replay',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-project-session-')),path=join(dir,'db');
 const projects=openProjectStore(path),accounts=openAccountStore(path),sessions=openSessionStore(path),peer=openSessionStore(path);
 const request={requestId:'one',baseRevision:0,name:'Game',snapshot:{version:1,projectId:'game',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}]}};
 try{
  for(const id of ['a','b'])accounts.put(id,{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  const token=sessions.issue('a',{ttlMs:60000}).token,foreign=sessions.issue('b',{ttlMs:60000}).token;
  const past=openSessionStore(path,{now:()=>Date.now()-10000});
  try{const expired=past.issue('a',{ttlMs:1}).token;assert.throws(()=>projects.saveSession('a',request,expired),/session required/);}finally{past.close();}
  for(const invalid of [undefined,'bad',foreign])assert.throws(()=>projects.saveSession('a',request,invalid),/session required/);
  assert.equal(projects.get('a','game'),null);
  assert.deepEqual(projects.saveSession('a',request,token),{cloudRevision:1,replayed:false});
  accounts.put('a',{enabled:false},{expectedVersion:1,actorId:'bootstrap'});
  assert.throws(()=>projects.saveSession('a',request,token),/account disabled/);
  accounts.put('a',{enabled:true},{expectedVersion:2,actorId:'bootstrap'});
  assert.deepEqual(projects.saveSession('a',request,token),{cloudRevision:1,replayed:true});
  peer.revoke(token);
  assert.throws(()=>projects.saveSession('a',request,token),/session required/);
  assert.throws(()=>projects.saveSession('a',{...request,requestId:'two',baseRevision:1},token),/session required/);
  assert.equal(projects.get('a','game').cloudRevision,1);assert.equal(projects.usage('a').versions,1);
 }finally{peer.close();sessions.close();accounts.close();projects.close();rmSync(dir,{recursive:true,force:true});}
});
