import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
test('account status is durable, versioned and atomic with its audit',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-accounts-')),path=join(dir,'accounts.db');let store=openAccountStore(path);
 const peer=openAccountStore(path),inspect=new DatabaseSync(path);
 try{
  assert.equal(store.isAllowed('missing'),false);
  assert.throws(()=>store.put('a',{enabled:true},{expectedVersion:0}),/identity/);
  store.put('a',{enabled:true},{expectedVersion:0,actorId:'admin'});
  assert.equal(peer.isAllowed('a'),true);
  peer.put('a',{enabled:false},{expectedVersion:1,actorId:'admin'});
  assert.throws(()=>store.put('a',{enabled:true},{expectedVersion:1,actorId:'admin'}),/version conflict/);
  store.close();store=openAccountStore(path);assert.equal(store.isAllowed('a'),false);
  inspect.exec("CREATE TRIGGER fail_account_audit BEFORE INSERT ON studio_account_audit BEGIN SELECT RAISE(ABORT,'audit failure'); END;");
  assert.throws(()=>store.put('a',{enabled:true},{expectedVersion:2,actorId:'admin'}),/audit failure/);
  assert.deepEqual(peer.get('a'),{accountId:'a',enabled:false,administrator:false,version:2});
  assert.equal(inspect.prepare('SELECT COUNT(*) AS count FROM studio_account_audit').get().count,2);
 }finally{inspect.close();peer.close();store.close();rmSync(dir,{recursive:true,force:true});}
});

test('existing accounts migrate without administrator rights and role updates remain versioned',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-account-role-')),path=join(dir,'accounts.db');
 const old=new DatabaseSync(path);old.exec("CREATE TABLE studio_accounts(id TEXT PRIMARY KEY,enabled INTEGER NOT NULL,version INTEGER NOT NULL); INSERT INTO studio_accounts VALUES('a',1,7)");old.close();
 const store=openAccountStore(path);
 try{
  assert.equal(store.isAllowed('a'),true);assert.equal(store.isAdministrator('a'),false);assert.equal(store.get('a').version,7);
  store.put('a',{enabled:true,administrator:true},{expectedVersion:7,actorId:'trusted-bootstrap'});
  assert.equal(store.isAdministrator('a'),true);
  store.put('a',{enabled:false},{expectedVersion:8,actorId:'trusted-bootstrap'});
  assert.equal(store.get('a').administrator,true);assert.equal(store.isAdministrator('a'),false);
  assert.throws(()=>store.put('a',{enabled:true,administrator:true},{expectedVersion:8,actorId:'trusted-bootstrap'}),/version conflict/);
  assert.equal(store.audit().items[0].before.administrator,false);assert.equal(store.audit().items[0].after.administrator,true);
  store.put('a',{enabled:true,administrator:false},{expectedVersion:9,actorId:'trusted-bootstrap'});assert.equal(store.isAdministrator('a'),false);
  assert.equal(store.isAdministrator('unknown'),false);
 }finally{store.close();rmSync(dir,{recursive:true,force:true});}
});

test('administrative account and audit pagination is bounded and retains disabled accounts',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-account-pages-')),store=openAccountStore(join(dir,'accounts.db'));
 try{
  for(const accountId of ['c','a','b'])store.put(accountId,{enabled:accountId!=='b'},{expectedVersion:0,actorId:'admin'});
  const first=store.list({limit:2});assert.deepEqual(first.items.map(item=>item.accountId),['a','b']);assert.equal(first.items[1].enabled,false);assert.equal(first.nextCursor,'b');
  const last=store.list({after:first.nextCursor,limit:2});assert.deepEqual(last.items.map(item=>item.accountId),['c']);assert.equal(last.nextCursor,null);
  assert.deepEqual(store.list({after:'z'}),{items:[],nextCursor:null});
  const audit=store.audit({limit:2});assert.equal(audit.nextCursor,2);assert.deepEqual(audit.items.map(item=>item.after.accountId),['c','a']);
  assert.equal(audit.items[0].actorId,'admin');assert.equal(audit.items[0].before,null);
  const remaining=store.audit({after:audit.nextCursor,limit:2});assert.equal(remaining.items.length,1);assert.equal(remaining.nextCursor,null);
  first.items[0].enabled=false;audit.items[0].after.enabled=false;assert.equal(store.get('a').enabled,true);assert.equal(store.audit().items[0].after.enabled,true);
  for(const limit of [0,101,1.5,Infinity]){assert.throws(()=>store.list({limit}));assert.throws(()=>store.audit({limit}));}
  assert.throws(()=>store.audit({after:-1}));assert.throws(()=>store.list({after:'\ud800'}));
 }finally{store.close();rmSync(dir,{recursive:true,force:true});}
});

test('administrator updates recheck authority and protect the last active administrator',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-admin-update-')),path=join(dir,'accounts.db'),store=openAccountStore(path),peer=openAccountStore(path);
 try{
  store.put('admin',{enabled:true,administrator:true},{expectedVersion:0,actorId:'bootstrap'});
  store.put('member',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  assert.throws(()=>store.updateByAdministrator('member',{enabled:false},{expectedVersion:1,actorId:'member'}),/authorization/);
  for(const changes of [{enabled:false},{enabled:true,administrator:false}])assert.throws(()=>store.updateByAdministrator('admin',changes,{expectedVersion:1,actorId:'admin'}),/last active/);
  assert.equal(store.get('admin').version,1);assert.equal(store.audit().items.length,2);
  store.updateByAdministrator('member',{enabled:true,administrator:true},{expectedVersion:1,actorId:'admin'});
  peer.updateByAdministrator('admin',{enabled:false},{expectedVersion:1,actorId:'member'});
  assert.throws(()=>store.updateByAdministrator('member',{enabled:false},{expectedVersion:2,actorId:'admin'}),/authorization/);
  assert.throws(()=>store.updateByAdministrator('member',{enabled:false},{expectedVersion:2,actorId:'member'}),/last active/);
  assert.throws(()=>store.updateByAdministrator('new',{enabled:true},{expectedVersion:0,actorId:'member'}),/Unknown account/);
  assert.equal(store.isAdministrator('member'),true);
 }finally{peer.close();store.close();rmSync(dir,{recursive:true,force:true});}
});

test('session-bound administrator writes reject revoked, foreign and expired sessions atomically',()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-admin-session-')),path=join(dir,'store.db'),store=openAccountStore(path),sessions=openSessionStore(path),expired=openSessionStore(path,{now:()=>0});
 try{
  store.put('admin',{enabled:true,administrator:true},{expectedVersion:0,actorId:'bootstrap'});
  store.put('member',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  const valid=sessions.issue('admin',{ttlMs:60000}),foreign=sessions.issue('member',{ttlMs:60000}),old=expired.issue('admin',{ttlMs:1});
  const write=token=>store.updateByAdministratorSession('member',{enabled:false},{expectedVersion:1,actorId:'admin',sessionToken:token});
  for(const token of [undefined,'bad',foreign.token,old.token])assert.throws(()=>write(token),/session required/);
  sessions.revoke(valid.token);assert.throws(()=>write(valid.token),/session required/);
  assert.equal(store.get('member').version,1);assert.equal(store.audit().items.length,2);
  const next=sessions.issue('admin',{ttlMs:60000});write(next.token);
  assert.equal(store.get('member').enabled,false);assert.equal(store.get('member').version,2);
  assert.equal(JSON.stringify(store.audit()).includes(next.token),false);
 }finally{expired.close();sessions.close();store.close();rmSync(dir,{recursive:true,force:true});}
});
