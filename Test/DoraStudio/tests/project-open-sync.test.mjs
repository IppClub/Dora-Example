import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const output=await build({entryPoints:[new URL('../apps/web/src/project-open-sync.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {synchronizeProjectForOpen}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
const snapshot=(projectId,revision,text)=>({version:1,projectId,revision,entry:'main.ts',files:[{path:'main.ts',kind:'text',text}]});
const local=(projectId,revision,text,updatedAt=100)=>({name:'当前项目',createdAt:1,updatedAt,snapshot:snapshot(projectId,revision,text)});

function storeFixture(project,record){
 let current=project,sync=record;const calls=[];
 return {calls,
  async load(){calls.push('load');return current;},
  async cloudSync(){calls.push('cloudSync');return sync;},
  async bindCloudBaseline(accountId,projectId,cloudRevision){calls.push(['bind',cloudRevision]);sync={accountId,projectId,cloudRevision};return sync;},
  async acceptCloudBaseline(accountId,projectId,cloudRevision){calls.push(['accept',cloudRevision]);sync={accountId,projectId,cloudRevision};return sync;},
  async save(name,input,baseRevision,checkpoint,_completion,cloudImport,cloudMerge){calls.push(['save',name,baseRevision,checkpoint,cloudImport,cloudMerge]);current={name,createdAt:1,updatedAt:500,snapshot:input};if(cloudImport)sync={accountId:cloudImport.accountId,projectId:input.projectId,cloudRevision:cloudImport.cloudRevision,syncedLocalRevision:input.revision};if(cloudMerge)sync={accountId:cloudMerge.accountId,projectId:input.projectId,cloudRevision:cloudMerge.cloudRevision,syncedLocalRevision:input.revision};return current;},
  async prepareCloudUpload(){},async confirmCloudUpload(){},async rejectCloudUpload(){},
 };
}

test('opening a project that only exists on another device materializes it before activation',async()=>{
 const store=storeFixture(undefined,undefined),stages=[];let choices=0;
 const result=await synchronizeProjectForOpen({store,projectId:'remote-only',accountId:'account',signal:new AbortController().signal,progress:stage=>stages.push(stage),chooseNewer:async()=>{choices++;return true;}},{loadRemote:async()=>({cloudRevision:3,updatedAt:400,name:'共享名称',snapshot:snapshot('remote-only',9,'remote')})});
 assert.equal(result.name,'共享名称');assert.equal(result.snapshot.revision,0);assert.equal(result.snapshot.files[0].text,'remote');assert.equal(choices,0);
 assert.ok(stages.some(stage=>stage.label==='正在保存到当前浏览器…'));
});

test('a genuinely newer synchronized copy asks once and applies the selected content',async()=>{
 const store=storeFixture(local('same',4,'local',100),{accountId:'account',projectId:'same',cloudRevision:2,syncedLocalRevision:4});let choices=0;
 const result=await synchronizeProjectForOpen({store,projectId:'same',accountId:'account',signal:new AbortController().signal,progress:()=>{},chooseNewer:async()=>{choices++;return true;}},{loadRemote:async()=>({cloudRevision:3,updatedAt:200,name:'新名称',snapshot:snapshot('same',8,'remote')})});
 assert.equal(choices,1);assert.equal(result.name,'新名称');assert.equal(result.snapshot.revision,5);assert.equal(result.snapshot.files[0].text,'remote');
 assert.ok(store.calls.some(call=>Array.isArray(call)&&call[0]==='accept'&&call[1]===3));
});

test('resuming the browser own pending upload does not masquerade as a newer-device change',async()=>{
 const project=local('pending',5,'latest local',300);const store=storeFixture(project,{accountId:'account',projectId:'pending',cloudRevision:2,syncedLocalRevision:4,pending:{requestId:'r',snapshot:snapshot('pending',4,'pending old'),name:'当前项目'}});let choices=0,resumes=0;
 const remotes=[{cloudRevision:2,updatedAt:200,name:'当前项目',snapshot:snapshot('pending',4,'old')},{cloudRevision:3,updatedAt:500,name:'当前项目',snapshot:snapshot('pending',4,'pending old')}];
 const result=await synchronizeProjectForOpen({store,projectId:'pending',accountId:'account',signal:new AbortController().signal,progress:()=>{},chooseNewer:async()=>{choices++;return true;}},{loadRemote:async()=>remotes.shift(),resumeUpload:async()=>{resumes++;store.calls.push('resume');const record=await store.cloudSync();record.cloudRevision=3;record.syncedLocalRevision=4;delete record.pending;},startUpload:async(_store,_account,current)=>{store.calls.push(['upload',current.snapshot.revision]);}});
 assert.equal(resumes,1);assert.equal(choices,0);assert.equal(result.snapshot.files[0].text,'latest local');assert.ok(store.calls.some(call=>Array.isArray(call)&&call[0]==='upload'&&call[1]===5));
});

test('missing synchronized server content blocks opening instead of pretending the project is current',async()=>{
 const store=storeFixture(local('missing',2,'local'),{accountId:'account',projectId:'missing',cloudRevision:4,syncedLocalRevision:2});
 await assert.rejects(()=>synchronizeProjectForOpen({store,projectId:'missing',accountId:'account',signal:new AbortController().signal,progress:()=>{},chooseNewer:async()=>false},{loadRemote:async()=>undefined}),/无法找到已同步/);
});
