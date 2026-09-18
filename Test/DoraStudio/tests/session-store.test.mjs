import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {openSessionStore} from '../apps/server/session-store.mjs';

test('sessions survive reopening, expire exactly, and revoke across connections without plaintext storage',t=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-sessions-')),path=join(dir,'sessions.db');
 t.after(()=>rmSync(dir,{recursive:true,force:true}));
 let timestamp=1000;const options={now:()=>timestamp};let store=openSessionStore(path,options);
 const first=store.issue('a',{ttlMs:1000}),second=store.issue('a',{ttlMs:5000}),other=store.issue('b',{ttlMs:5000});
 assert.notEqual(first.token,second.token);assert.match(first.token,/^[A-Za-z0-9_-]{43}$/);
 store.close();store=openSessionStore(path,options);
 const peer=openSessionStore(path,options),inspect=new DatabaseSync(path);
 try{
  const rows=inspect.prepare('SELECT * FROM studio_sessions').all();assert.equal(rows.length,3);
  for(const issued of [first,second,other])assert.equal(JSON.stringify(rows).includes(issued.token),false);
  assert.deepEqual(store.resolve(first.token),{accountId:'a',expiresAt:2000});
  timestamp=2000;assert.equal(store.resolve(first.token),null);
  peer.revoke(second.token);assert.equal(store.resolve(second.token),null);peer.revoke(second.token);
  const next=store.issue('a',{ttlMs:1000});peer.revokeAccount('a');assert.equal(store.resolve(next.token),null);
  assert.equal(store.resolve(other.token).accountId,'b');
  assert.equal(store.resolve('fake'),null);assert.equal(store.resolve('x'.repeat(43)),null);
  assert.throws(()=>store.issue('a',{ttlMs:0}),/lifetime/);assert.throws(()=>store.issue('a',{ttlMs:Infinity}),/lifetime/);
  assert.throws(()=>store.issue('\ud800',{ttlMs:10}),/account/);
  timestamp=999;assert.equal(store.resolve(other.token),null);
 }finally{inspect.close();peer.close();store.close();}
});
