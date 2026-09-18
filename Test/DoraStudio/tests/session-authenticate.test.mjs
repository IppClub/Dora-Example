import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {createSessionAuthenticator,SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';

test('cookie authentication requires a live session and explicit current account authorization',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-session-auth-')),sessions=openSessionStore(join(dir,'sessions.db'));
 t.after(()=>{sessions.close();rmSync(dir,{recursive:true,force:true});});
 const {token}=sessions.issue('account',{ttlMs:60000});let allowed=true,calls=0;
 const authenticate=createSessionAuthenticator({sessions,allowAccount:async id=>{calls++;assert.equal(id,'account');return allowed;}});
 const request=cookie=>({headers:{cookie,'x-account-id':'forged'}});
 assert.deepEqual(await authenticate(request(`other=ok; ${SESSION_COOKIE_NAME}=${token}`)),{accountId:'account'});
 allowed=false;assert.equal(await authenticate(request(`${SESSION_COOKIE_NAME}=${token}`)),null);
 const before=calls;
 for(const cookie of [undefined,'',`${SESSION_COOKIE_NAME}=${token}; ${SESSION_COOKIE_NAME}=${token}`,`${SESSION_COOKIE_NAME}="${token}"`,`${SESSION_COOKIE_NAME}=bad`,`${SESSION_COOKIE_NAME}=${token}\n`,'x'.repeat(8193)])assert.equal(await authenticate(request(cookie)),null);
 assert.equal(calls,before);
 const revoking=createSessionAuthenticator({sessions,allowAccount:async()=>{sessions.revoke(token);return true;}});
 assert.equal(await revoking(request(`${SESSION_COOKIE_NAME}=${token}`)),null);
 allowed=true;assert.equal(await authenticate(request(`${SESSION_COOKIE_NAME}=${token}`)),null);
 assert.throws(()=>createSessionAuthenticator({sessions}),/dependencies/);
});
