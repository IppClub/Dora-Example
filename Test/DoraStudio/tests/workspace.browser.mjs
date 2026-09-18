import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { build } from 'esbuild';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const bundle = await build({ stdin: { contents: `export * from './workspace'; export * from './agent-project-writeback'; export * from './agent-project-writeback-flow'; export * from './agent-edit-backend'; export * from './agent-captures'; export * from './agent-capture-batch';
export {createEditHandler} from '../../../packages/agent-contracts/dist/edit-handler.js';
export {createDeleteHandler} from '../../../packages/agent-contracts/dist/delete-handler.js';
export {validateDeleteFile} from '../../../packages/agent-contracts/dist/delete-validation.js';
export {getToolDefinition} from '../../../packages/agent-contracts/dist/index.js';
export {validateEditFile} from '../../../packages/agent-contracts/dist/edit-validation.js';
export {executeAgentToolDefinition} from '../../../packages/agent-contracts/dist/executor.js';`, loader: 'ts', resolveDir: new URL('../apps/web/src/', import.meta.url).pathname },
  bundle: true, format: 'esm', platform: 'browser', write: false, target: 'es2022' });
const server = createServer((req, res) => {
  if (req.url === '/workspace.js') { res.setHeader('content-type', 'text/javascript'); res.end(bundle.outputFiles[0].contents); }
  else { res.setHeader('content-type', 'text/html'); res.end('<!doctype html><title>Studio storage verification</title>'); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.STUDIO_CHROME_PATH ? { executablePath: process.env.STUDIO_CHROME_PATH } : {}) });
  const context = await browser.newContext();
  const page = await context.newPage(), other = await context.newPage();
  const url = `http://127.0.0.1:${server.address().port}`;
  const errors = [];
  for (const p of [page, other]) { p.on('pageerror', error => errors.push(error.message)); await p.goto(url); }
  const creationResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');let store=await LocalWorkspace.open('creation-intent');
    const snapshot={version:1,projectId:'idea-game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export const x=1'}]};
    try{
      let emptyRejected=false;try{await store.createFromPrompt('空想法',{...snapshot,projectId:'empty'},'account','  ');}catch(error){emptyRejected=error.code==='invalid';}
      const first=await store.createFromPrompt('初次创作',snapshot,'account','  做一个小游戏  ');
      const listed=await store.list();
      let duplicateRejected=false;try{await store.createFromPrompt('重复',snapshot,'account','另一个描述');}catch(error){duplicateRejected=error.code==='conflict';}
      store.close();store=await LocalWorkspace.open('creation-intent');
      const reopened=await store.load('idea-game');
      const revised=await store.save('初次创作',{...snapshot,revision:1,files:[{path:'main.ts',kind:'text',text:'export const x=2'}]},0,true);
      return {emptyRejected,duplicateRejected,firstPrompt:first.creation.prompt,reopenedPrompt:reopened.creation.prompt,revisedPrompt:revised.creation.prompt,summaryHasPrompt:'creation' in listed[0],checkpoint:(await store.loadCheckpoint('idea-game',0)).snapshot.files[0].text};
    }finally{store.close();}
  });
  assert.deepEqual(creationResult,{emptyRejected:true,duplicateRejected:true,firstPrompt:'做一个小游戏',reopenedPrompt:'做一个小游戏',revisedPrompt:'做一个小游戏',summaryHasPrompt:false,checkpoint:'export const x=1'});
  const existingProjectResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');const store=await LocalWorkspace.open('existing-project-agent');
    try{
      const snapshot={version:1,projectId:'blank-game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]};
      await store.save('空白项目',snapshot,null);
      const creation=await store.beginProjectAgent('blank-game',0,'account','  增加跳跃玩法  ','grant');
      let duplicate=false;try{await store.beginProjectAgent('blank-game',0,'account','重复','grant');}catch(error){duplicate=error.code==='conflict';}
      let stale=false;try{await store.beginProjectAgent('missing-game',0,'account','描述','grant');}catch(error){stale=error.code==='conflict';}
      const reopened=await store.load('blank-game');
      return {prompt:creation.prompt,grantId:creation.grantId,persisted:reopened.creation.prompt,revision:reopened.snapshot.revision,duplicate,stale};
    }finally{store.close();}
  });
  assert.deepEqual(existingProjectResult,{prompt:'增加跳跃玩法',grantId:'grant',persisted:'增加跳跃玩法',revision:0,duplicate:true,stale:true});
  const dispatchResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');let store=await LocalWorkspace.open('creation-dispatch');
    try{
      const snapshot={version:1,projectId:'model-game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]};
      const project=await store.createFromPrompt('模型创作',snapshot,'account','做一个小游戏','grant');
      const id=project.creation.requestId;
      const attempted=await store.markPromptDispatch('model-game',id,'attempted');
      let repeated=false;try{await store.markPromptDispatch('model-game',id,'attempted');}catch(error){repeated=error.code==='conflict';}
      store.close();store=await LocalWorkspace.open('creation-dispatch');
      const persisted=(await store.load('model-game')).creation.dispatchState;
      const confirmed=await store.markPromptDispatch('model-game',id,'confirmed',19);
      let rebound=false;try{await store.markPromptDispatch('model-game',crypto.randomUUID(),'confirmed',20);}catch(error){rebound=error.code==='conflict';}
      const writeback=await store.markAgentWriteback('model-game',id,19,'attempted');
      let duplicateWriteback=false;try{await store.markAgentWriteback('model-game',id,19,'attempted');}catch(error){duplicateWriteback=error.code==='conflict';}
      store.close();store=await LocalWorkspace.open('creation-dispatch');
      const persistedWriteback=(await store.load('model-game')).creation.writebackState;
      let wrongTask=false;try{await store.markAgentWriteback('model-game',id,20,'confirmed',0);}catch(error){wrongTask=error.code==='conflict';}
      let wrongRevision=false;try{await store.markAgentWriteback('model-game',id,19,'confirmed',1);}catch(error){wrongRevision=error.code==='conflict';}
      const received=await store.markAgentWriteback('model-game',id,19,'confirmed',0);
      return {grantId:confirmed.grantId,requestId:id,attempted:attempted.dispatchState,persisted,confirmed:confirmed.dispatchState,taskId:confirmed.taskId,repeated,rebound,
        writeback:writeback.writebackState,persistedWriteback,received:received.writebackState,writebackRevision:received.writebackRevision,duplicateWriteback,wrongTask,wrongRevision,
        summaryPrivate:!('creation' in (await store.list())[0])};
    }finally{store.close();}
  });
  assert.match(dispatchResult.requestId,/^[0-9a-f-]{36}$/i);
  assert.deepEqual({...dispatchResult,requestId:'uuid'},{grantId:'grant',requestId:'uuid',attempted:'attempted',persisted:'attempted',confirmed:'confirmed',taskId:19,repeated:true,rebound:true,
    writeback:'attempted',persistedWriteback:'attempted',received:'confirmed',writebackRevision:0,duplicateWriteback:true,wrongTask:true,wrongRevision:true,summaryPrivate:true});
  const iterationResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');let store=await LocalWorkspace.open('agent-iterations');
    const snapshot={version:1,projectId:'continued-game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]};
    try{
      const project=await store.createFromPrompt('持续创作',snapshot,'account','首轮','grant'),firstId=project.creation.requestId;
      await store.markPromptDispatch('continued-game',firstId,'attempted');await store.markPromptDispatch('continued-game',firstId,'confirmed',1);
      const round=await store.beginAgentIteration('continued-game','account','  增加雨滴  ','grant');
      const attempted=await store.markAgentIterationDispatch('continued-game',round.requestId,'attempted');
      const confirmed=await store.markAgentIterationDispatch('continued-game',round.requestId,'confirmed',2);
      const next=await store.beginAgentIteration('continued-game','account','增加星光','grant');
      await store.markAgentIterationWriteback('continued-game',round.requestId,2,'attempted');
      store.close();store=await LocalWorkspace.open('agent-iterations');
      const reopened=await store.load('continued-game'),received=await store.markAgentIterationWriteback('continued-game',round.requestId,2,'confirmed',0);
      return {prompt:round.prompt,attempted:attempted.dispatchState,confirmed:confirmed.dispatchState,taskId:confirmed.taskId,
        initialWriteback:reopened.creation.writebackState??null,reopened:reopened.iterations[0].writebackState,received:received.writebackState,revision:received.writebackRevision,nextPrompt:next.prompt,
        summaryPrivate:!('iterations' in (await store.list())[0])};
    }finally{store.close();}
  });
  assert.deepEqual(iterationResult,{prompt:'增加雨滴',attempted:'attempted',confirmed:'confirmed',taskId:2,initialWriteback:null,reopened:'attempted',received:'confirmed',revision:0,nextPrompt:'增加星光',summaryPrivate:true});
  const syncResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');let first=await LocalWorkspace.open('cloud-pending');const second=await LocalWorkspace.open('cloud-pending');
    try{
      const snapshot={version:1,projectId:'game',revision:4,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}]};
      await first.prepareCloudUpload('a',snapshot,'request','Game');snapshot.files[0].text='changed';
      let blocked=false;try{await second.prepareCloudUpload('a',snapshot,'other','Game');}catch(error){blocked=error.code==='conflict';}
      first.close();first=await LocalWorkspace.open('cloud-pending');
      const pending=await first.cloudSync('a','game'),other=await second.cloudSync('b','game');
      let mismatch=false;try{await second.confirmCloudUpload('a','game','wrong',1);}catch(error){mismatch=error.code==='conflict';}
      await second.confirmCloudUpload('a','game','request',1);
      const confirmed=await first.cloudSync('a','game');
      await first.prepareCloudUpload('a',snapshot,'next','Game');
      return {blocked,mismatch,isolated:other===undefined,text:pending.pending.snapshot.files[0].text,confirmed,nextBase:(await second.cloudSync('a','game')).cloudRevision};
    }finally{first.close();second.close();}
  });
  assert.deepEqual(syncResult,{blocked:true,mismatch:true,isolated:true,text:'print(1)',confirmed:{accountId:'a',projectId:'game',cloudRevision:1,syncedLocalRevision:4},nextBase:1});
  const cloudImportResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');const store=await LocalWorkspace.open('cloud-original-import');
    try{
      const snapshot={version:1,projectId:'original',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'},{path:'raw.bin',kind:'binary',bytes:new Uint8Array([0,255])}]};
      await store.save('云项目',snapshot,null,false,undefined,{accountId:'a',cloudRevision:8});
      let duplicate=false;try{await store.save('覆盖',snapshot,null,false,undefined,{accountId:'a',cloudRevision:9});}catch(error){duplicate=error.code==='conflict';}
      await store.prepareCloudUpload('a',snapshot,'next','Game');
      const record=await store.cloudSync('a','original');
      // An existing pending binding must not be replaced even without a project.
      await store.prepareCloudUpload('a',{...snapshot,projectId:'pending'},'pending-request','Pending');
      let blocked=false;try{await store.save('不能覆盖',{...snapshot,projectId:'pending'},null,false,undefined,{accountId:'a',cloudRevision:3});}catch(error){blocked=error.code==='conflict';}
      return {duplicate,blocked,base:record.cloudRevision,localRevision:(await store.load('original')).snapshot.revision,absent:(await store.load('pending'))===undefined,pending:(await store.cloudSync('a','pending')).pending.requestId};
    }finally{store.close();}
  });
  assert.deepEqual(cloudImportResult,{duplicate:true,blocked:true,base:8,localRevision:0,absent:true,pending:'pending-request'});
  const mergeCommit=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');const store=await LocalWorkspace.open('cloud-merge-commit');
    const snapshot={version:1,projectId:'merge',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'before'}]};
    try{
      await store.save('merge',snapshot,null,false,undefined,{accountId:'a',cloudRevision:2});
      const merged={...snapshot,revision:1,files:[{path:'init.lua',kind:'text',text:'merged'}]};
      let stale=false;try{await store.save('merge',merged,0,true,undefined,undefined,{accountId:'a',expectedCloudRevision:1,cloudRevision:3});}catch(error){stale=error.code==='conflict';}
      const before=(await store.load('merge')).snapshot.revision;
      await store.save('merge',merged,0,true,undefined,undefined,{accountId:'a',expectedCloudRevision:2,cloudRevision:3});
      const checkpoint=await store.loadCheckpoint('merge',0),binding=await store.cloudSync('a','merge');
      await store.prepareCloudUpload('a',merged,'pending','Game');
      let pending=false;try{await store.save('merge',{...merged,revision:2},1,true,undefined,undefined,{accountId:'a',expectedCloudRevision:3,cloudRevision:4});}catch(error){pending=error.code==='conflict';}
      return {stale,before,checkpoint:checkpoint.snapshot.files[0].text,cloudRevision:binding.cloudRevision,pending,localRevision:(await store.load('merge')).snapshot.revision,checkpoints:await store.listCheckpoints('merge')};
    }finally{store.close();}
  });
  assert.deepEqual(mergeCommit,{stale:true,before:0,checkpoint:'before',cloudRevision:3,pending:true,localRevision:1,checkpoints:[0]});
  const archiveResult=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js'),name='studio-archive-upgrade';
    await new Promise((resolve,reject)=>{const open=indexedDB.open(name,3);open.onupgradeneeded=()=>{for(const table of ['projects','assets','retired'])open.result.createObjectStore(table,{keyPath:table==='assets'?'hash':'projectId'});open.result.createObjectStore('checkpoints',{keyPath:['snapshot.projectId','snapshot.revision']});open.result.createObjectStore('visionReservations',{keyPath:['projectId','taskId']});};open.onerror=()=>reject(open.error);open.onsuccess=()=>{open.result.close();resolve();};});
    let store=await LocalWorkspace.open(name);
    const input={version:1,kind:'project-archive',projectId:'binary-only',revision:0,entry:null,files:[{path:'init.wasm',kind:'binary',bytes:new Uint8Array([0,97,115,109])}]};
    const saved=await store.preserveArchive('待适配',input);input.files[0].bytes[0]=9;saved.archive.files[0].bytes[1]=9;
    let duplicate=false,executable=false,quota=false;
    try{await store.preserveArchive('Duplicate',input);}catch(error){duplicate=error.code==='conflict';}
    try{await store.save('Wrong',{version:1,projectId:'binary-only',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:''}]},null);}catch(error){executable=error.code==='conflict';}
    const add=IDBObjectStore.prototype.add;
    try{IDBObjectStore.prototype.add=function(...args){if(this.name==='archives')throw new DOMException('Injected quota','QuotaExceededError');return add.apply(this,args);};await store.preserveArchive('Failed',{...input,projectId:'failed'});}catch(error){quota=error.code==='quota';}finally{IDBObjectStore.prototype.add=add;}
    store.close();store=await LocalWorkspace.open(name);
    try{return {duplicate,executable,quota,bytes:[...(await store.loadArchive('binary-only')).archive.files[0].bytes],failed:await store.loadArchive('failed')===undefined,projects:(await store.list()).length};}finally{store.close();}
  });
  assert.deepEqual(archiveResult,{duplicate:true,executable:true,quota:true,bytes:[0,97,115,109],failed:true,projects:0});
  const writeback=await page.evaluate(async()=>{
    const {LocalWorkspace,commitAgentWriteback}=await import('/workspace.js');
    const store=await LocalWorkspace.open('studio-agent-writeback');
    try{
      const initial=await store.save('Writeback',{version:1,projectId:'writeback',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'return 1'}]},null);
      const files=[{path:'init.lua',bytes:new TextEncoder().encode('return 2')},{path:'asset.bin',bytes:new Uint8Array([0,255])}];
      const originalPut=IDBObjectStore.prototype.put;
      let quotaRejected=false;
      try{
        IDBObjectStore.prototype.put=function(...args){
          if(this.name==='projects')throw new DOMException('injected writeback quota','QuotaExceededError');
          return originalPut.apply(this,args);
        };
        await commitAgentWriteback(store,initial.snapshot,files);
      }catch(error){quotaRejected=error.code==='quota';}
      finally{IDBObjectStore.prototype.put=originalPut;}
      const afterFailure=await store.load('writeback');
      if(!quotaRejected||afterFailure.snapshot.revision!==0||afterFailure.snapshot.files.length!==1||afterFailure.snapshot.files[0].text!=='return 1')throw Error('Failed writeback changed author data');
      if((await store.listCheckpoints('writeback')).length!==0)throw Error('Failed writeback retained checkpoint');
      const result=await commitAgentWriteback(store,initial.snapshot,files);
      if(!result.committed||result.project.snapshot.revision!==1)throw Error('Writeback did not commit');
      const checkpoint=await store.loadCheckpoint('writeback',0);
      if(checkpoint.snapshot.files[0].text!=='return 1')throw Error('Missing author rollback checkpoint');
      let stale=false;try{await commitAgentWriteback(store,initial.snapshot,files);}catch{stale=true;}
      if(!stale)throw Error('Stale writeback accepted');
      const noChange=await commitAgentWriteback(store,result.project.snapshot,files);
      if(noChange.committed||noChange.project.snapshot.revision!==1)throw Error('No-op advanced revision');
      // Simulate an edit after proposal validation, before the actual CAS save.
      const save=store.save.bind(store);
      store.save=async(...args)=>{
        await save('Concurrent',{...result.project.snapshot,revision:2,files:[{path:'init.lua',kind:'text',text:'user edit'}]},1);
        return save(...args);
      };
      let raced=false;
      try{await commitAgentWriteback(store,result.project.snapshot,[{path:'init.lua',bytes:new TextEncoder().encode('agent edit')}]);}catch(error){raced=error.code==='conflict';}
      const latest=await store.load('writeback');
      if(!raced||latest.snapshot.files[0].text!=='user edit')throw Error('Concurrent edit overwritten');
      return {committed:true,checkpoint:true,staleRejected:true,noOp:true,lateConflict:true,quotaRollback:true};
    }finally{store.close();}
  });
  assert.deepEqual(writeback,{committed:true,checkpoint:true,staleRejected:true,noOp:true,lateConflict:true,quotaRollback:true});
  await page.evaluate(async()=>{
    const {LocalWorkspace,reconcileAgentProject}=await import('/workspace.js');
    const store=await LocalWorkspace.open('studio-writeback-flow');
    try{
      const base=await store.save('Flow',{version:1,projectId:'flow',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'before'}]},null);
      let acknowledged;
      const host={projectId:'flow',captureProject:async()=>({projectId:'flow',generation:'g',sessionId:1,reconciliationRequired:true,files:[{path:'init.lua',bytes:new TextEncoder().encode('after')}]}),syncProject:async snapshot=>{acknowledged=snapshot;throw Error('host disconnected');}};
      const failed=await reconcileAgentProject(store,host,base.snapshot,new AbortController().signal);
      if(failed.hostConfirmed||!failed.committed||failed.project.snapshot.revision!==1||acknowledged.revision!==1)throw Error('Lost committed version on host failure');
      const persisted=await store.load('flow');
      if(persisted.snapshot.files[0].text!=='after')throw Error('Author write missing');
      host.syncProject=async snapshot=>{acknowledged=snapshot;};
      const retried=await reconcileAgentProject(store,host,persisted.snapshot,new AbortController().signal);
      if(!retried.hostConfirmed||retried.committed||retried.project.snapshot.revision!==1)throw Error('Confirmation retry duplicated author commit');
      let release,entered;
      const gate=new Promise(resolve=>{release=resolve;}),started=new Promise(resolve=>{entered=resolve;});
      const capture=host.captureProject;let captures=0;
      host.captureProject=async()=>{captures++;entered();await gate;return capture();};
      const first=reconcileAgentProject(store,host,persisted.snapshot,new AbortController().signal);
      await started;
      let refused=false;
      try{await reconcileAgentProject(store,host,persisted.snapshot,new AbortController().signal);}catch(error){refused=error.message.includes('already in progress');}
      release();await first;
      if(!refused||captures!==1)throw Error('Duplicate writeback was dispatched');
      host.captureProject=async()=>{throw Error('capture failed');};
      try{await reconcileAgentProject(store,host,persisted.snapshot,new AbortController().signal);}catch{}
      host.captureProject=capture;
      const recovered=await reconcileAgentProject(store,host,persisted.snapshot,new AbortController().signal);
      if(!recovered.hostConfirmed)throw Error('Failed capture retained operation lock');
      const beforeAbort=new AbortController();
      host.captureProject=async()=>{
        beforeAbort.abort(new Error('cancel capture'));
        return {...await capture(),files:[{path:'init.lua',bytes:new TextEncoder().encode('must not save')}]};
      };
      let cancelled=false;try{await reconcileAgentProject(store,host,persisted.snapshot,beforeAbort.signal);}catch{cancelled=true;}
      const unchanged=await store.load('flow');
      if(!cancelled||unchanged.snapshot.revision!==1||unchanged.snapshot.files[0].text!=='after')throw Error('Cancelled capture wrote author files');
      const afterAbort=new AbortController();
      host.captureProject=async()=>({...await capture(),files:[{path:'init.lua',bytes:new TextEncoder().encode('saved before cancellation')}]});
      host.syncProject=async()=>{afterAbort.abort(new Error('cancel acknowledgement'));};
      const afterCommit=await reconcileAgentProject(store,host,persisted.snapshot,afterAbort.signal);
      if(!afterCommit.committed||afterCommit.hostConfirmed||afterCommit.project.snapshot.revision!==2)throw Error('Cancellation lost author commit state');
      const durable=await store.load('flow');
      if(durable.snapshot.files[0].text!=='saved before cancellation'||durable.snapshot.revision!==2)throw Error('Cancellation undid committed author files');
    }finally{store.close();}
  });
  const captureStorage = await page.evaluate(async () => {
    const {LocalWorkspace,saveAgentCaptures}=await import('/workspace.js');
    const store=await LocalWorkspace.open('studio-capture-storage');
    try {
      const oldCaptures=Array.from({length:60},(_,i)=>({path:`.agent/vision/${1000000000+i}-1.png`,kind:'binary',bytes:new Uint8Array([i])}));
      const project=await store.save('Capture',{version:1,projectId:'capture',revision:0,entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'return 1'},...oldCaptures,{path:'.agent/vision/reference.png',kind:'binary',bytes:new Uint8Array([9])}]},null);
      const canvas=document.createElement('canvas');canvas.width=2;canvas.height=2;
      canvas.getContext('2d').fillRect(0,0,2,2);
      const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));
      const event={version:1,sessionId:'s',requestId:'r',projectId:'capture',revision:0,runId:'run',captureId:'one',type:'gameCaptured',width:2,height:2,png:new Uint8Array(await blob.arrayBuffer())};
      const saved=await saveAgentCaptures(store,project,'run',[event],new AbortController().signal);
      await store.reserveVisionCapture('capture',1,'rollback',1);
      const originalPut=IDBObjectStore.prototype.put;
      let rolledBack=false;
      try {
        IDBObjectStore.prototype.put=function(...args){if(this.name==='projects') throw new DOMException('injected quota','QuotaExceededError');return originalPut.apply(this,args);};
        await store.save(saved.project.name,{...saved.project.snapshot,revision:2},1,true,
          {taskId:1,operationId:'rollback',success:true,interrupted:false,files:saved.files});
      } catch(error) {rolledBack=error.code==='quota';}
      finally {IDBObjectStore.prototype.put=originalPut;}
      const rolledBackReservation=await store.reserveVisionCapture('capture',1,'rollback',1);
      const loaded=await store.load('capture');
      let conflict=false,foreign=false;
      try {await saveAgentCaptures(store,project,'run',[event],new AbortController().signal);}catch(error){conflict=error.code==='conflict';}
      try {await saveAgentCaptures(store,saved.project,'other',[event],new AbortController().signal);}catch{foreign=true;}
      return {rolledBack,completionAbsent:rolledBackReservation.result===undefined,revision:loaded.snapshot.revision,path:saved.files[0],binary:loaded.snapshot.files.find(f=>f.path===saved.files[0])?.kind,conflict,foreign,checkpoints:await store.listCheckpoints('capture'),removed:saved.removedFiles,
        userImagePreserved:loaded.snapshot.files.some(f=>f.path==='.agent/vision/reference.png'),
        generatedCount:loaded.snapshot.files.filter(f=>/^\.agent\/vision\/\d+-\d+\.png$/.test(f.path)).length};
    } finally {store.close();}
  });
  assert.equal(captureStorage.revision,1);assert.equal(captureStorage.binary,'binary');
  assert.match(captureStorage.path,/^\.agent\/vision\/\d+-\d+\.png$/);
  assert.equal(captureStorage.conflict,true);assert.equal(captureStorage.foreign,true);
  assert.deepEqual(captureStorage.checkpoints,[0]);
  assert.equal(captureStorage.generatedCount,60);assert.equal(captureStorage.userImagePreserved,true);
  assert.equal(captureStorage.rolledBack,true);assert.equal(captureStorage.completionAbsent,true);
  assert.deepEqual(captureStorage.removed,['.agent/vision/1000000000-1.png']);
  const reservations=await page.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');
    let first=await LocalWorkspace.open('vision-reservations'),second=await LocalWorkspace.open('vision-reservations');
    try {
      await first.save('Budget',{version:1,projectId:'budget',revision:0,entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'return 1'}]},null);
      const results=await Promise.allSettled(Array.from({length:4},(_,i)=>(i%2?first:second).reserveVisionCapture('budget',1,`op-${i}`,2)));
      const accepted=results.findIndex(result=>result.status==='fulfilled');
      first.close();first=await LocalWorkspace.open('vision-reservations');
      const replay=await first.reserveVisionCapture('budget',1,`op-${accepted}`,2);
      let changed=false;
      try{await first.reserveVisionCapture('budget',1,`op-${accepted}`,1);}catch(error){changed=error.code==='conflict';}
      const independent=await second.reserveVisionCapture('budget',2,'new-task',1);
      await second.completeVisionCaptureFailure('budget',2,'new-task',0,'cancelled before first frame',true);
      second.close();second=await LocalWorkspace.open('vision-reservations');
      const failure=await second.reserveVisionCapture('budget',2,'new-task',1);
      const unchanged=await second.load('budget');
      let overwriteRejected=false;
      try{await second.completeVisionCaptureFailure('budget',2,'new-task',0,'different result',false);}catch(error){overwriteRejected=error.code==='conflict';}
      return {accepted:results.filter(result=>result.status==='fulfilled').length,quota:results.filter(result=>result.status==='rejected' && result.reason.code==='quota').length,replay,changed,independent,failure,revision:unchanged.snapshot.revision,overwriteRejected};
    } finally {first.close();second.close();}
  });
  assert.equal(reservations.accepted,3);assert.equal(reservations.quota,1);
  assert.equal(reservations.replay.replayed,true);assert.equal(reservations.replay.budget.captureFrameCount,6);
  assert.equal(reservations.changed,true);assert.equal(reservations.independent.budget.captureFrameCount,1);
  assert.equal(reservations.failure.result.success,false);assert.equal(reservations.failure.result.interrupted,true);
  assert.deepEqual(reservations.failure.result.files,[]);assert.equal(reservations.revision,0);assert.equal(reservations.overwriteRejected,true);
  const crashed=await context.newPage();await crashed.goto(url);
  await crashed.evaluate(async()=>{
    const {LocalWorkspace}=await import('/workspace.js');
    const store=await LocalWorkspace.open('capture-crash-recovery');
    await store.save('Crash',{version:1,projectId:'crash',revision:0,entry:'main.lua',files:[{path:'main.lua',kind:'text',text:'return 1'}]},null);
    window.locked=navigator.locks.request(JSON.stringify(['dora-studio-capture','crash',1,'op']),async()=>{
      await store.reserveVisionCapture('crash',1,'op',1,JSON.stringify({revision:0,times:[0]}));
      window.reserved=true;await new Promise(()=>{});
    });
  });
  await crashed.waitForFunction(()=>window.reserved===true);
  await other.evaluate(async()=>{
    const {LocalWorkspace,captureAgentRunBatch}=await import('/workspace.js');
    const store=await LocalWorkspace.open('capture-crash-recovery');const project=await store.load('crash');
    const run={projectId:'crash',revision:0,runId:'replacement',capture(){throw new Error('MUST_NOT_RECAPTURE');}};
    window.recovery=captureAgentRunBatch(store,project,run,1,'op',[0],new AbortController().signal).then(result=>{window.recovered=result;return result;}).finally(()=>store.close());
  });
  await other.waitForFunction(async()=> (await navigator.locks.query()).pending.some(lock=>lock.name.includes('crash')));
  assert.equal(await other.evaluate(()=>window.recovered===undefined),true);
  await crashed.close();
  const crashRecovered=await other.evaluate(()=>window.recovery);
  assert.equal(crashRecovered.success,false);assert.equal(crashRecovered.interrupted,true);assert.equal(crashRecovered.restored,true);
  assert.equal(crashRecovered.visionBudget.captureBatchCount,1);assert.deepEqual(crashRecovered.files,[]);
  const migration = await page.evaluate(async () => {
    const name = 'studio-workspace-v1-upgrade';
    const bytes = new Uint8Array([0, 255, 128]);
    const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(byte => byte.toString(16).padStart(2, '0')).join('');
    const legacy = await new Promise((resolve, reject) => {
      const opening = indexedDB.open(name, 1);
      opening.onupgradeneeded = () => {
        opening.result.createObjectStore('projects', { keyPath: 'projectId' });
        opening.result.createObjectStore('assets', { keyPath: 'hash' });
        opening.result.createObjectStore('retired', { keyPath: 'projectId' });
      };
      opening.onsuccess = () => resolve(opening.result); opening.onerror = () => reject(opening.error);
    });
    await new Promise((resolve, reject) => {
      const tx = legacy.transaction(['projects', 'assets'], 'readwrite');
      tx.objectStore('projects').put({ projectId: 'legacy', name: '旧项目', revision: 7, entry: 'main.lua', createdAt: 1, updatedAt: 2,
        files: [{ path: 'main.lua', kind: 'text', text: 'return 7' }, { path: 'asset.bin', kind: 'binary', hash }] });
      tx.objectStore('assets').put({ hash, bytes, references: 1 });
      tx.oncomplete = resolve; tx.onabort = () => reject(tx.error);
    });
    legacy.close();
    const { LocalWorkspace, createLocalEditBackend, createEditHandler, createDeleteHandler, validateDeleteFile, getToolDefinition, validateEditFile, executeAgentToolDefinition } = await import('/workspace.js');
    const upgraded = await LocalWorkspace.open(name);
    const before = await upgraded.load('legacy');
    await upgraded.save(before.name, { ...before.snapshot, revision: 8 }, 7, true);
    upgraded.close();
    const reopened = await LocalWorkspace.open(name);
    const after = await reopened.load('legacy'), checkpoint = await reopened.loadCheckpoint('legacy', 7);
    const writer = createLocalEditBackend(reopened, after, 1);
    const staleWriter = createLocalEditBackend(reopened, after, 2);
    const committed = await writer.applyFileChanges(1, 'legacy', [{ path: 'main.lua', op: 'write', content: 'return 9' }]);
    const conflict = await staleWriter.applyFileChanges(2, 'legacy', [{ path: 'main.lua', op: 'write', content: 'stale' }]);
    const savedEdit = await reopened.load('legacy'), editCheckpoint = await reopened.loadCheckpoint('legacy', 8);
    const toolBackend = createLocalEditBackend(reopened, savedEdit, 3);
    const definition = { ...getToolDefinition('edit_file'), validateInput: validateEditFile, handler: createEditHandler(toolBackend) };
    const toolContext = { role: 'main', workMode: 'code', disabledAgentTools: [], taskId: 3, workingDir: 'legacy', workflow: {},
      cancellation: { isCancelled: () => false, reason: () => undefined } };
    const toolResult = await executeAgentToolDefinition(definition, { edits: [
      { path: 'main.lua', old_str: 'return 9', new_str: 'return 10' },
      { path: '../outside.lua', old_str: '', new_str: 'unsafe' },
      { path: 'asset.bin', old_str: '', new_str: 'binary overwrite' }
    ] }, toolContext, { searchDoraDocLimitMax: 20 });
    reopened.close();
    const finalStore = await LocalWorkspace.open(name);
    const finalProject = await finalStore.load('legacy'), toolCheckpoint = await finalStore.loadCheckpoint('legacy', 9);
    const restoredProject = await finalStore.restoreCheckpoint('legacy', 9, 10);
    const restoreCheckpoint = await finalStore.loadCheckpoint('legacy', 10);
    let staleRestore;
    try { await finalStore.restoreCheckpoint('legacy', 9, 10); } catch (error) { staleRestore = error.code; }
    const afterStaleRestore = await finalStore.load('legacy');
    const deleteBackend = createLocalEditBackend(finalStore, afterStaleRestore, 4);
    const deleteDefinition = { ...getToolDefinition('delete_file'), validateInput: validateDeleteFile, handler: createDeleteHandler(deleteBackend) };
    const deletion = await executeAgentToolDefinition(deleteDefinition, { target_file: 'asset.bin' }, { ...toolContext, taskId: 4, workflow: {} }, { searchDoraDocLimitMax: 20 });
    const deletedProject = await finalStore.load('legacy');
    const restoredDeletion = await finalStore.restoreCheckpoint('legacy', 11, 12);
    const invalidDeletion = await createLocalEditBackend(finalStore, restoredDeletion, 5).deleteFile(5, 'legacy', 'main.lua');
    const afterInvalidDeletion = await finalStore.load('legacy');
    finalStore.close();
    return { before, after, checkpoint, committed, conflict, savedEdit, editCheckpoint, toolResult, finalProject, toolCheckpoint,
      restoredProject, restoreCheckpoint, staleRestore, afterStaleRestore, deletion, deletedProject, restoredDeletion, invalidDeletion, afterInvalidDeletion };
  });
  assert.equal(migration.before.snapshot.revision, 7);
  assert.equal(migration.before.snapshot.files[0].text, 'return 7');
  assert.deepEqual(Object.values(migration.before.snapshot.files[1].bytes), [0, 255, 128]);
  assert.deepEqual(migration.checkpoint, migration.before);
  assert.equal(migration.after.snapshot.revision, 8);
  assert.equal(migration.committed.success, true);
  assert.equal(migration.conflict.success, false);
  assert.equal(migration.savedEdit.snapshot.files[0].text, 'return 9');
  assert.equal(migration.savedEdit.snapshot.revision, 9);
  assert.deepEqual(migration.editCheckpoint, migration.after);
  assert.equal(migration.toolResult.output.partial, true);
  assert.equal(migration.toolResult.output.actualSaved, true);
  assert.equal(migration.toolResult.output.succeededOperationCount, 1);
  assert.equal(migration.toolResult.output.failedOperationCount, 2);
  assert.equal(migration.finalProject.snapshot.revision, 10);
  assert.equal(migration.finalProject.snapshot.files[0].text, 'return 10');
  assert.deepEqual(Object.values(migration.finalProject.snapshot.files[1].bytes), [0, 255, 128]);
  assert.deepEqual(migration.toolCheckpoint, migration.savedEdit);
  assert.equal(migration.restoredProject.snapshot.revision, 11);
  assert.equal(migration.restoredProject.snapshot.files[0].text, 'return 9');
  assert.deepEqual(migration.restoreCheckpoint, migration.finalProject);
  assert.equal(migration.staleRestore, 'conflict');
  assert.deepEqual(migration.afterStaleRestore, migration.restoredProject);
  assert.equal(migration.deletion.output.success, true);
  assert.equal(migration.deletion.output.reversible, true);
  assert.equal(migration.deletion.output.binary, true);
  assert.equal(migration.deletedProject.snapshot.files.length, 1);
  assert.deepEqual(Object.values(migration.restoredDeletion.snapshot.files[1].bytes), [0, 255, 128]);
  assert.equal(migration.invalidDeletion.success, false);
  assert.deepEqual(migration.afterInvalidDeletion, migration.restoredDeletion);
  const init = async p => p.evaluate(async () => {
    const { LocalWorkspace } = await import('/workspace.js');
    window.store = await LocalWorkspace.open('studio-workspace-test');
    window.makeSnapshot = (projectId, revision = 0, text = 'return 42', bytes = [0, 1, 255]) => ({
      version: 1, projectId, revision, entry: 'main.lua', files: [
        { path: 'main.lua', kind: 'text', text },
        { path: 'images/a.bin', kind: 'binary', bytes: new Uint8Array(bytes) },
        { path: 'images/b.bin', kind: 'binary', bytes: new Uint8Array(bytes) },
      ],
    });
    window.assetStats = async () => {
      const db = await new Promise((resolve, reject) => { const r = indexedDB.open('studio-workspace-test'); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
      try {
        return await new Promise((resolve, reject) => {
          const r = db.transaction('assets').objectStore('assets').getAll();
          r.onsuccess = () => resolve(r.result.map(a => ({ hash: a.hash, references: a.references, bytes: [...a.bytes] })).sort((a, b) => a.hash.localeCompare(b.hash)));
          r.onerror = () => reject(r.error);
        });
      } finally { db.close(); }
    };
  });
  await init(page); await init(other);
  const first = await page.evaluate(async () => {
    const snapshot = makeSnapshot('one');
    const pending = store.save('项目一', snapshot, null);
    snapshot.files[0].text = 'mutated'; snapshot.files[1].bytes[0] = 99;
    await pending;
    await store.save('项目二', makeSnapshot('two'), null);
    const project = await store.load('one');
    const result = { text: project.snapshot.files[0].text, bytes: [...project.snapshot.files[1].bytes], assets: await assetStats(), list: await store.list() };
    store.close(); return result;
  });
  assert.equal(first.text, 'return 42'); assert.deepEqual(first.bytes, [0, 1, 255]);
  assert.equal(first.assets.length, 1); assert.equal(first.assets[0].references, 2); assert.equal(first.list.length, 2);
  await page.reload(); await init(page);
  assert.equal(await page.evaluate(async () => (await store.load('one')).snapshot.files[0].text), 'return 42');

  const race = await Promise.all([page, other].map((p, i) => p.evaluate(async i => {
    try { await store.save('项目一', makeSnapshot('one', 1, `return ${i}`), 0); return 'saved'; }
    catch (error) { return error.code; }
  }, i)));
  assert.deepEqual(race.sort(), ['conflict', 'saved']);
  const rollback = await page.evaluate(async () => {
    const before = await store.load('one'), assetsBefore = await assetStats();
    const original = IDBObjectStore.prototype.put;
    IDBObjectStore.prototype.put = function (...args) {
      // Inject the quota failure after asset requests, before the project record commits.
      if (this.name === 'projects') throw new DOMException('Injected storage quota failure', 'QuotaExceededError');
      return original.apply(this, args);
    };
    let failure;
    try { await store.save('未保存', makeSnapshot('one', 2, 'return 99', [9, 8, 7]), 1); }
    catch (error) { failure = error.code; }
    finally { IDBObjectStore.prototype.put = original; }
    return { failure, before, after: await store.load('one'), assetsBefore, assetsAfter: await assetStats() };
  });
  assert.equal(rollback.failure, 'quota'); assert.deepEqual(rollback.after, rollback.before);
  assert.deepEqual(rollback.assetsAfter, rollback.assetsBefore);

  const aborted = await page.evaluate(async () => {
    const before = await store.load('one'), assetsBefore = await assetStats();
    const original = IDBObjectStore.prototype.put;
    IDBObjectStore.prototype.put = function (...args) {
      const r = original.apply(this, args);
      if (this.name === 'projects') r.addEventListener('success', () => this.transaction.abort(), { once: true });
      return r;
    };
    let failure;
    try { await store.save('中止保存', makeSnapshot('one', 2, 'return 123', [3, 2, 1]), 1, true); }
    catch (error) { failure = error.code; }
    finally { IDBObjectStore.prototype.put = original; }
    return { failure, before, after: await store.load('one'), assetsBefore, assetsAfter: await assetStats() };
  });
  assert.equal(aborted.failure, 'unavailable'); assert.deepEqual(aborted.before, aborted.after);
  assert.deepEqual(aborted.assetsBefore, aborted.assetsAfter);

  const recovered = await page.evaluate(async () => {
    const beforeCheckpoint = await store.load('one');
    await store.save('已恢复', makeSnapshot('one', 2, 'return 99', [9, 8, 7]), 1, true);
    const checkpoint = await store.loadCheckpoint('one', 1);
    if (JSON.stringify(checkpoint) !== JSON.stringify(beforeCheckpoint)) throw new Error('Checkpoint did not preserve the old project');
    let staleDelete, invalid, duplicate;
    try { await store.remove('one', 1); } catch (error) { staleDelete = error.code; }
    try { await store.save('bad', makeSnapshot('one', 4), 2); } catch (error) { invalid = error.code; }
    try { await store.save('duplicate', makeSnapshot('one'), null); } catch (error) { duplicate = error.code; }
    const assets = await assetStats();
    await store.remove('one', 2);
    if (await store.loadCheckpoint('one', 1)) throw new Error('Deleted project retained its checkpoint');
    const remaining = await assetStats(), remainingProject = await store.load('two');
    await store.remove('two', 0);
    const empty = await assetStats();
    let retired; try { await store.save('recreated', makeSnapshot('one'), null); } catch (error) { retired = error.code; }
    store.close();
    let closed; try { await store.list(); } catch (error) { closed = error.code; }
    return { staleDelete, invalid, duplicate, assets, remaining, remainingProject, empty, closed, retired };
  });
  assert.equal(recovered.staleDelete, 'conflict'); assert.equal(recovered.invalid, 'invalid');
  assert.equal(recovered.duplicate, 'conflict'); assert.equal(recovered.closed, 'closed');
  assert.equal(recovered.retired, 'conflict');
  assert.equal(recovered.assets.length, 2); assert.ok(recovered.assets.every(a => a.references === 1));
  assert.equal(recovered.remaining.length, 1); assert.deepEqual(recovered.remaining[0].bytes, [0, 1, 255]);
  assert.equal(recovered.remainingProject.snapshot.projectId, 'two'); assert.deepEqual(recovered.empty, []);
  await other.evaluate(() => store.close());
  assert.deepEqual(errors, []);
  console.log(`PASS Chrome ${browser.version()}: v1 migration/checkpoint reopen, real IndexedDB reload, binary copy/dedup, two-tab atomic conflict, injected quota rollback, recovery and reference cleanup.`);
} finally {
  await browser?.close(); await new Promise(resolve => server.close(resolve));
}
