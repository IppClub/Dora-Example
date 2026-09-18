import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createServer} from 'node:http';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {openLoginStore} from '../apps/server/login-store.mjs';
import {createLoginRoute} from '../apps/server/login-route.mjs';

test('single-use invite, password login, admin invitation and session cookie',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-login-')),path=join(dir,'db.sqlite');
  const accounts=openAccountStore(path),sessions=openSessionStore(path),login=openLoginStore(path);
  try{
    const {code}=login.issueInvite({administrator:true});
    assert.throws(()=>login.issueInvite({administrator:true}),/UNIQUE constraint failed/);
    assert.equal(await login.redeem({code,accountId:'admin',password:'long-test-password-123'}).then(row=>row.accountId),'admin');
    assert.equal(accounts.isAdministrator('admin'),true);
    await assert.rejects(login.redeem({code,accountId:'other',password:'long-test-password-123'}),/Invitation unavailable/);
    assert.equal(await login.verify({accountId:'admin',password:'wrong',remoteKey:'test'}),false);
    assert.equal(await login.verify({accountId:'admin',password:'long-test-password-123',remoteKey:'test'}),true);
    assert.equal(await login.verify({accountId:'absent',password:'long-test-password-123',remoteKey:'test'}),false);
    const {token}=sessions.issue('admin',{ttlMs:60000});
    const creator=login.issueInvite({createdBy:'admin',actorSessionToken:token});
    assert.equal((await login.redeem({code:creator.code,accountId:'author',password:'another-long-password'})).accountId,'author');
    assert.equal(accounts.isAdministrator('author'),false);
    sessions.revoke(token);
    assert.throws(()=>login.issueInvite({createdBy:'admin',actorSessionToken:token}),/Administrator session required/);
    accounts.put('author',{enabled:false},{expectedVersion:1,actorId:'admin'});
    assert.equal(await login.verify({accountId:'author',password:'another-long-password',remoteKey:'test'}),false);
    assert.throws(()=>createLoginRoute({studioOrigin:'http://127.0.0.1:8898',login,sessions,accounts}),/HTTPS/);
    const route=createLoginRoute({studioOrigin:'https://127.0.0.1:9999',login,sessions,accounts});
    const plain=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
    try{
      await new Promise(resolve=>plain.listen(0,'127.0.0.1',resolve));
      const response=await fetch(`http://127.0.0.1:${plain.address().port}/api/auth/login`,{method:'POST',headers:{origin:'https://127.0.0.1:9999','content-type':'application/json'},body:JSON.stringify({accountId:'admin',password:'long-test-password-123'})});
      assert.equal(response.status,403);
    }finally{await new Promise(resolve=>plain.close(resolve));}
  }finally{login.close();sessions.close();accounts.close();rmSync(dir,{recursive:true,force:true});}
});
