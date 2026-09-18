import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/byok-configurations-client.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const {decodeByokConfigurations}=await import(`data:text/javascript;base64,${Buffer.from(built.outputFiles[0].text).toString('base64')}`);
test('configuration decoder owns validated public data and rejects hidden secrets or unsafe selections',()=>{
 const item={id:'a',label:'My model',model:'model',providerId:'provider',enabled:true,version:1};
 const source={version:1,configurations:[item],nextCursor:null},copy=decodeByokConfigurations(source);
 item.label='changed';assert.equal(copy.configurations[0].label,'My model');
 for(const change of [{id:'../foreign'},{key:'unexpected-secret'},{ownerId:'other'},{enabled:'true'},{version:0}])assert.throws(()=>decodeByokConfigurations({...source,configurations:[{...item,...change}]}));
 assert.throws(()=>decodeByokConfigurations({...source,configurations:[item,item]}));
 assert.throws(()=>decodeByokConfigurations({...source,nextCursor:'foreign'}));
 assert.throws(()=>decodeByokConfigurations({...source,nextCursor:undefined}));
});
