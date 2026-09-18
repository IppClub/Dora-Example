import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:[new URL('../apps/web/src/model-grants-client.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {decodeModelGrants}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('shared configuration decoder excludes secrets and accepts skipped-binding pagination',()=>{
 const row={grantId:'g',label:'平台',model:'model',enabled:true},page={version:1,configurations:[row],nextCursor:null};
 assert.deepEqual(decodeModelGrants(page).configurations,[row]);assert.deepEqual(decodeModelGrants({version:1,configurations:[],nextCursor:'missing'}),{configurations:[],nextCursor:'missing'});
 for(const input of [{...page,configurations:[{...row,key:'secret'}]},{...page,configurations:[row,row]},{...page,nextCursor:undefined},{...page,configurations:[{...row,grantId:'../g'}]}])assert.throws(()=>decodeModelGrants(input));
 const owned=decodeModelGrants(page);row.label='changed';assert.equal(owned.configurations[0].label,'平台');
});
