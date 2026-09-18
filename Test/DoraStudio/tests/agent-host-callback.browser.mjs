import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {build} from 'esbuild';
import {createAgentHostSnapshot} from '../scripts/agent-host-snapshot.mjs';
import {createAgentHostRoute} from '../apps/server/agent-host-route.mjs';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
import {createAgentLaunchRoute} from '../apps/server/agent-launch-route.mjs';
import {createAgentLaunchRevokeRoute} from '../apps/server/agent-launch-revoke-route.mjs';
const launchBundle=await build({stdin:{contents:"export * from './agent-launch-client'; export {startWorkspaceAgent} from './workspace-agent';",loader:'ts',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser'});
const adapterBundle=await build({stdin:{contents:"export {writeAgentProjectBaseline} from './agent-project-baseline'; export {installAgentProjectSnapshot,readInstalledAgentFiles} from './agent-project-install'; export {mountAgentHostFrame} from './agent-host-frame'; export {createAgentWasmSource} from './agent-wasm-source'; export {serveAgentSessionPort} from './agent-session-port-host'; export {connectAgentSessionPort} from './agent-session-port'; export {installAgentWasmHost} from './agent-wasm-host'; export {connectAgentFrameSession} from './agent-frame-session';",loader:'ts',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser'});
const panelBundle=await build({stdin:{contents:"import {createRoot} from 'react-dom/client'; import {AgentSessionPanel} from './AgentSessionPanel'; export function mount(controller,persist,retirement){const root=createRoot(document.getElementById('panel'));root.render(<AgentSessionPanel controller={controller} persist={persist} retirement={retirement}/>);return ()=>root.unmount();}",loader:'tsx',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser',jsx:'automatic',loader:{'.css':'empty'}});
const panelCss=await readFile('apps/web/src/style.css','utf8')+'\n'+await readFile('apps/web/src/agent-panel.css','utf8');
const receivedGameSource=`local Dora=require('Dora')
local node=Dora.DrawNode()
node.size=Dora.Size(360,180)
node:drawPolygon({Dora.Vec2(-180,-90),Dora.Vec2(180,-90),Dora.Vec2(180,90),Dora.Vec2(-180,90)},Dora.Color(0xff4cc38a))
node:onTapBegan(function() print('STUDIO_WRITEBACK_POINTER') end)
Dora.Director.ui:addChild(node)
print('STUDIO_WRITEBACK_GAME_READY')`;
const appBundle=await build({stdin:{contents:`
import {createRoot} from 'react-dom/client';
import {App} from './App';
import {LocalWorkspace} from './workspace';
export {LocalWorkspace};
export async function mount(hostOrigin,playerConfig){
 globalThis.studioTestPlayerConfig=playerConfig;
 const store=await LocalWorkspace.open();
 for(const [projectId,name] of [['owned','Alpha'],['other','Beta']]){
  if(!await store.load(projectId))await store.save(name,projectId==='owned'?{version:1,projectId,revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'error("AUTHOR_MUST_NOT_RUN")'},{path:'Resources/test.bin',kind:'binary',bytes:new Uint8Array([0,255,128])}]}:{version:1,projectId,revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export const value = 1;'}]},null);
 }
 let owned=await store.load('owned');
 while(owned.snapshot.revision<8)owned=await store.save(owned.name,{...owned.snapshot,revision:owned.snapshot.revision+1,files:owned.snapshot.files.map(file=>file.path==='init.lua'?{...file,text:'-- author offline edit'}:file)},owned.snapshot.revision);
 await store.bindCloudBaseline('test-account','owned',1);
 store.close();createRoot(document.getElementById('root')).render(<App agentHostOrigin={hostOrigin} accountId="test-account"/>);
}
`,loader:'tsx',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser',jsx:'automatic',define:{'import.meta.env.BASE_URL':'"/"','import.meta.env.VITE_DORA_RUNTIME_URL':'globalThis.studioTestPlayerConfig.url','import.meta.env.VITE_DORA_ENGINE_BUILD':'globalThis.studioTestPlayerConfig.engineBuild'},loader:{'.css':'empty'}});
const lifecycleBundle=await build({entryPoints:['apps/web/src/agent-persist-stopped.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.STUDIO_PLAYWRIGHT_MODULE||'playwright');
const root=resolve('../build/studio-agent-host');
const features=JSON.parse(await readFile(resolve(root,'dora-web-features.json'),'utf8'));
assert.equal(features.studioAgentHost,true,'Require an explicitly marked trusted-host build');
const lua=`assert(type(_studio_agent_emit)=='function')
assert(_studio_agent_emit('{"kind":"unicode","value":"中文回调"}'))
assert(not _studio_agent_emit('{"kind":"throw"}'))
local ok=pcall(function() _studio_agent_emit(string.rep('x',1048577)) end)
assert(not ok)
local Session=require('Agent.Session')
local HostSession=require('AgentHostSession')
do
  local Content=require('Dora').Content
  local Checkpoint=require('Agent.Tool.Checkpoint')
  local Commits=require('Agent.Runtime.FileCommitEvents')
  local project='/user/commit-test'
  assert(Content:mkdir(project) or Content:exist(project))
  local task=Checkpoint.createTask('batch notification test','code')
  assert(task.success)
  local observed={}
  local stop=Commits.subscribeFileCommits(project,function(payload) observed[#observed+1]=payload end)
  local applied=Checkpoint.applyFileChanges(task.taskId,project,{{path='a.lua',op='create',content='return 1'},{path='b.lua',op='create',content='return 2'}})
  assert(applied.success and #observed==1)
  local batch=require('Agent.Utils').safeJsonDecode(observed[1])
  assert(batch.checkpointId==applied.checkpointId and batch.checkpointSeq==applied.checkpointSeq and #batch.changes==2)
  assert(Content:load(project..'/a.lua')=='return 1' and Content:load(project..'/b.lua')=='return 2')
  local failed=Checkpoint.applyFileChanges(task.taskId,project,{{path='../escape.lua',op='write',content='x'}})
  assert(not failed.success and #observed==1)
  local checkpoint=Checkpoint.getCheckpoint(applied.checkpointId)
  local diff=Checkpoint.getCheckpointDiff(applied.checkpointId)
  assert(checkpoint.status=='APPLIED' and checkpoint.taskId==task.taskId)
  assert(diff.success and #diff.files==2)
  assert(diff.files[1].beforeExists==false and diff.files[1].afterExists==true)
  assert(Checkpoint.rollbackCheckpoint(applied.checkpointId,project).success)
  assert(not Content:exist(project..'/a.lua') and not Content:exist(project..'/b.lua'))
  local reverted=Checkpoint.getCheckpoint(applied.checkpointId)
  local historical=Checkpoint.getCheckpointDiff(applied.checkpointId)
  assert(reverted.id==checkpoint.id and reverted.status=='REVERTED')
  assert(historical.success and historical.files[1].afterExists==true)
  assert(_studio_agent_emit('{"kind":"checkpoint-recovery-semantics-verified"}'))
  stop();Checkpoint.setTaskStatus(task.taskId,'DONE')
  assert(_studio_agent_emit('{"kind":"file-commit-batch-verified"}'))
end
assert(not pcall(function() HostSession.startConfigured('{"version":1,"projectRoot":"/game","title":"bad","apiKey":"forbidden"}') end))
assert(not pcall(function() HostSession.startConfigured('{"version":2,"projectRoot":"/game","title":"bad"}') end))
local created={success=true,session=HostSession.prepare('/game','原 Agent 宿主桥接')}
local restored=HostSession.prepare('/game','must not replace title')
assert(restored.id==created.session.id and restored.title==created.session.title)
assert(not pcall(function() HostSession.prepare('/game/../other','invalid') end))
local Admission=require('Agent.Runtime.TaskAdmission')
local release=Admission.holdProjectTaskAdmission('/game')
local releaseSecond=Admission.holdProjectTaskAdmission('/game')
assert(Admission.isProjectTaskAdmissionClosed('/game'))
assert(not Admission.isProjectTaskAdmissionClosed('/other'))
local denied=Session.sendPrompt(created.session.id,'must not start')
assert(not denied.success and denied.message=='project task admission is closed')
assert(Session.getCurrentTaskId(created.session.id)==nil)
release();release()
assert(Admission.isProjectTaskAdmissionClosed('/game'))
releaseSecond()
assert(not Admission.isProjectTaskAdmissionClosed('/game'))
assert(not Session.beginProjectTaskQuiescence(999999).success)
local quiet=Session.beginProjectTaskQuiescence(created.session.id)
assert(quiet.success and quiet.projectRoot=='/game')
local state=quiet.poll()
assert(state.success and state.quiescent and #state.pending==0)
assert(Admission.isProjectTaskAdmissionClosed('/game'))
assert(not Session.sendPrompt(created.session.id,'still blocked').success)
local relatedBefore=#Session.getSession(created.session.id).relatedSessions
local deniedChild=Session.createSubSession(created.session.id,'Must not create')
assert(not deniedChild.success and deniedChild.message=='project task admission is closed')
assert(#Session.getSession(created.session.id).relatedSessions==relatedBefore)
quiet.close();quiet.close()
assert(not quiet.poll().success)
assert(not Admission.isProjectTaskAdmissionClosed('/game'))
local bridge=require('AgentSessionBridge').open(created.session.id)
local studioEntry=require('Script.Dev.Entry')
assert(studioEntry.getCurrentEntryStatus().success and not studioEntry.getCurrentEntryStatus().running)
local started,reason=studioEntry.enterEntryAsync({fileName='/game/user-script.lua'})
assert(not started and reason:find('isolated browser Player',1,true))
assert(Session.setWorkMode(created.session.id,'plan').success)
do
  local Events=require('Agent.Runtime.FileCommitEvents')
  local Utils=require('Agent.Utils')
  for i=1,33 do
    local payload=Utils.safeJsonEncode({version=1,taskId=1,checkpointId=1000+i,checkpointSeq=i,changes={{path='overflow-'..i..'.lua',op='write'}}})
    Events.publishFileCommit('/game',payload)
    if i==1 then Events.publishFileCommit('/game',payload) end
    if i==32 then assert(not Admission.isProjectTaskAdmissionClosed('/game')) end
  end
  assert(Admission.isProjectTaskAdmissionClosed('/game'))
  _studio_agent_request(Utils.safeJsonEncode({operation='snapshot',sessionId=created.session.id,requestId='overflow-check'}))
end
bridge.close();bridge.close()
assert(Admission.isProjectTaskAdmissionClosed('/game'))
bridge.releaseQuiescence()
assert(not Admission.isProjectTaskAdmissionClosed('/game'))
do
  local Events=require('Agent.Runtime.FileCommitEvents')
  local Utils=require('Agent.Utils')
  local function batch(id,path)
    return Utils.safeJsonEncode({version=1,taskId=1,checkpointId=id,checkpointSeq=id,changes={{path=path,op='write'}}})
  end
  local largeChanges={}
  for i=1,220 do largeChanges[i]={path=string.rep('a',150)..i..'.lua',op='write'} end
  local large=Utils.safeJsonEncode({version=1,taskId=1,checkpointId=2001,checkpointSeq=1,changes=largeChanges})
  local largeNext=Utils.safeJsonEncode({version=1,taskId=1,checkpointId=2002,checkpointSeq=2,changes=largeChanges})
  assert(#large<65536 and #large+#largeNext>65536)
  local cases={
    {'byte-overflow-check',large,largeNext},
    {'conflicting-notification-check',batch(3001,'first.lua'),batch(3001,'changed.lua')},
    {'invalid-notification-check',batch(4001,'valid.lua'),'not json'},
    {'oversized-notification-check',batch(5001,'valid.lua'),string.rep('x',65537)}
  }
  for _,case in ipairs(cases) do
    local current=require('AgentSessionBridge').open(created.session.id)
    Events.publishFileCommit('/game',case[2])
    assert(not Admission.isProjectTaskAdmissionClosed('/game'))
    Events.publishFileCommit('/game',case[3])
    assert(Admission.isProjectTaskAdmissionClosed('/game'))
    _studio_agent_request(Utils.safeJsonEncode({operation='snapshot',sessionId=created.session.id,requestId=case[1]}))
    current.close()
    assert(Admission.isProjectTaskAdmissionClosed('/game'))
    current.releaseQuiescence()
    assert(not Admission.isProjectTaskAdmissionClosed('/game'))
  end
end
assert(Session.setWorkMode(created.session.id,'code').success)
require('AgentSessionBridge').open(created.session.id)
do
  local Checkpoint=require('Agent.Tool.Checkpoint')
  local task=Checkpoint.createTask('queued batch','code')
  assert(task.success)
  local result=Checkpoint.applyFileChanges(task.taskId,'/game',{{path='queued-author.lua',op='create',content='return 42'}})
  assert(result.success)
  Checkpoint.setTaskStatus(task.taskId,'DONE')
end
local Dora=require('Dora')
assert(Dora.Content:mkdir('/stop-test'))
assert(Dora.Content:mkdir('/other-stop-test'))
local target=Session.createSession('/stop-test','Stop test')
assert(target.success,target.message)
local child=Session.createSubSession(target.session.id,'Stop child')
local other=Session.createSession('/other-stop-test','Other project')
assert(target.success and child.success and other.success)
local config={url='STUDIO_STREAM_MODEL_URL',model='fixture',apiKey='local-test-only',contextWindow=64000,temperature=0,maxTokens=128,supportsFunctionCalling=true,customOptions={auxiliaryOptions={test=true}}}
Dora.thread(function()
for _,id in ipairs({target.session.id,child.session.id,other.session.id}) do
  assert(_studio_agent_emit('{"kind":"stage","value":"send '..id..'"}'))
  local sent=Session.sendPrompt(id,'Do not modify files.',nil,'code',nil,config)
  assert(sent.success,sent.message)
end
Dora.sleep(1)
assert(_studio_agent_emit('{"kind":"stage","value":"poll"}'))
local stopping=Session.beginProjectTaskQuiescence(target.session.id)
local first=stopping.poll()
assert(_studio_agent_emit('{"kind":"stage","value":"polled"}'))
assert(first.success and not first.quiescent and #first.pending==2)
for _,task in ipairs(first.pending) do assert(task.stopRequested and not task.finalizing) end
assert(Session.getSession(other.session.id).session.currentTaskStatus=='RUNNING')
local otherStop=Session.beginProjectTaskQuiescence(other.session.id)
assert(not otherStop.poll().quiescent)
assert(_studio_agent_emit('{"kind":"stage","value":"waiting"}'))
Dora.thread(function()
  local deadline=Dora.App.runningTime+10
  repeat
    Dora.sleep(0.05)
    local result=stopping.poll()
    assert(result.success)
    if result.quiescent and otherStop.poll().quiescent then
      assert(Session.getSession(target.session.id).session.currentTaskStatus=='STOPPED')
      assert(Session.getSession(child.session.id).session.currentTaskStatus=='STOPPED')
      stopping.close();otherStop.close()
      assert(_studio_agent_emit('{"kind":"complete"}'))
      return
    end
  until Dora.App.runningTime>deadline
  error('Project task quiescence timed out')
end)
end)`;
const supportManifest=JSON.parse(await readFile('dist/agent-host/manifest.json','utf8'));
const compiledAgent=await Promise.all(supportManifest.files.filter(file=>file.path.startsWith('lua/')).map(async file=>{
  const bytes=await readFile('dist/agent-host/'+file.path);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),file.sha256);
  return {path:file.path.slice(4),text:bytes.toString('utf8')};
}));
assert.ok(compiledAgent.some(file=>file.path==='Agent/Session.lua'));
const sources=[{path:'init.lua',text:lua},{path:'AgentHostSession.lua',text:await readFile('dist/agent-host/AgentHostSession.lua','utf8')},{path:'AgentSessionBridge.lua',text:await readFile('dist/agent-host/AgentSessionBridge.lua','utf8')},{path:'StudioAgentEntry.lua',text:await readFile('dist/agent-host/StudioAgentEntry.lua','utf8')},{path:'StudioAgentYueBuild.lua',text:await readFile('dist/agent-host/StudioAgentYueBuild.lua','utf8')},{path:'StudioAgentXmlBuild.lua',text:await readFile('dist/agent-host/StudioAgentXmlBuild.lua','utf8')},...compiledAgent];
const html=await readFile(resolve(root,'dora-player-runtime.html'),'utf8');
const restoreLua=`local Session=require('Agent.Session')
local hostSession=require('AgentHostSession').prepare('/game','must not replace restored title')
assert(hostSession.id==1 and hostSession.title=='原 Agent 宿主桥接' and hostSession.projectRoot=='/game')
local main=Session.getSession(2)
local child=Session.getSession(3)
assert(main.success and child.success)
assert(main.session.currentTaskStatus=='STOPPED' and child.session.currentTaskStatus=='STOPPED')
assert(require('Dora').Content:load('/user/settings/agent-barrier.txt')=='barrier-confirmed')
assert(_studio_agent_emit('{"kind":"restored","main":"STOPPED","child":"STOPPED"}'))`;
const activeLua=`local Session=require('Agent.Session')
local main=Session.createSession('/game','Active bridge test')
assert(main.success)
local child=Session.createSubSession(main.session.id,'Active child')
assert(child.success)
require('AgentSessionBridge').open(main.session.id)
local config={url='STUDIO_STREAM_MODEL_URL',model='fixture',apiKey='local-test-only',contextWindow=64000,temperature=0,maxTokens=128,supportsFunctionCalling=true,customOptions={auxiliaryOptions={test=true}}}
for _,id in ipairs({main.session.id,child.session.id}) do
  local sent=Session.sendPrompt(id,'Do not modify files.',nil,'code',nil,config)
  assert(sent.success,sent.message)
end
require('Dora').thread(function()
  require('Dora').sleep(1)
  assert(_studio_agent_emit('{"kind":"active-ready"}'))
end)`;
const activeRestoreLua=`local Session=require('Agent.Session')
for _,id in ipairs({1,2}) do
  local detail=Session.getSession(id)
  assert(detail.success and detail.session.currentTaskStatus=='STOPPED')
  local found=false
  for _,message in ipairs(detail.messages) do
    if message.role=='user' and message.content=='Do not modify files.' then found=true end
  end
  assert(found,'User message missing after restore')
end
assert(_studio_agent_emit('{"kind":"active-restored"}'))`;
const isolatedLua=`assert(not require('Agent.Session').getSession(1).success)
assert(not require('Dora').Content:exist('/user/settings/agent-barrier.txt'))
assert(_studio_agent_emit('{"kind":"isolated"}'))`;
const captureLua=`local Content=require('Dora').Content
assert(Content:mkdir('/user/studio-project'))
local session=require('AgentHostSession').prepare('/user/studio-project','Capture')
require('AgentSessionBridge').open(session.id)
local Checkpoint=require('Agent.Tool.Checkpoint')
local task=Checkpoint.createTask('Studio tool capture integration','code')
assert(task.success)
local applied=Checkpoint.applyFileChanges(task.taskId,'/user/studio-project',{{path='init.lua',op='create',content='return 42'},{path='temporary.lua',op='create',content='return 0'}})
assert(applied.success)
assert(Checkpoint.getCheckpoint(applied.checkpointId).status=='APPLIED')
assert(Checkpoint.deleteFile(task.taskId,'/user/studio-project','temporary.lua').success)
Checkpoint.setTaskStatus(task.taskId,'DONE')
assert(_studio_agent_emit('{"kind":"capture-ready","sessionId":'..session.id..'}'))`;
const hostSupport=await readFile('dist/agent-host/host.js','utf8');
const ownedTitle='原 Agent "宿主" · 中文';
let ownedData;
let ownedLaunch;
const launchStore=createAgentLaunchStore();
const hostData=(mode='normal')=>{
if(mode==='owned' && ownedData)return ownedData;
const config={version:1,parentOrigin:`http://127.0.0.1:${parentServer.address().port}`,accountId:'test-account',projectId:mode==='isolated'?'other-project':mode==='owned'?'owned':'test-project',generation:mode==='owned'?'owned-generation':'test-generation',projectRoot:'/game',title:mode==='owned'?ownedTitle:'原 Agent 宿主桥接'};
const files=sources.map(file=>({path:file.path,bytes:[...Buffer.from((file.path==='init.lua'&&mode!=='normal'?({capture:captureLua,owned:"require('AgentHostSession').startConfigured(require('Dora').Content:load('/game/studio-host.json'))",restore:restoreLua,active:activeLua,'active-restore':activeRestoreLua,isolated:isolatedLua}[mode]):file.text).replace('STUDIO_STREAM_MODEL_URL',`http://127.0.0.1:${server.address().port}/stream-model`))]}));
if(mode==='owned')files.push({path:'studio-host.json',bytes:[...Buffer.from(JSON.stringify({version:1,projectRoot:config.projectRoot,title:config.title}))]});
const manifest={format:'dora-web-game',version:1,engineVersion:'1.9.2',profile:'dora-preset',entry:'init.lua',files:files.map(file=>({path:file.path,url:file.path,size:file.bytes.length,sha256:createHash('sha256').update(Buffer.from(file.bytes)).digest('hex'),startup:true}))};
return {config,files,manifest};
};
const injection=(mode='normal')=>{
const {config,files,manifest}=hostData(mode);
return `<script>
const studioHostConfig=${JSON.stringify(config)};
window.agentCallbackEvents=[];
Module.print=(...args)=>console.log(...args);
Module.printErr=(...args)=>console.error(...args);
Module.doraStudioAgentEvent=payload=>{const value=JSON.parse(payload);if(value.kind==='throw')throw Error('expected callback failure');if(value.kind==='stage')console.log(payload);window.agentCallbackEvents.push(value);};
Module.doraSnapshot=Promise.resolve({manifest:${JSON.stringify(manifest)},files:${JSON.stringify(files)}.map(file=>({path:file.path,bytes:new Uint8Array(file.bytes)}))});
Module.doraStorageId=import('/storage.js').then(async({agentStorageId,acquireAgentStorage,decodeAgentHostConfig})=>{
  const config=decodeAgentHostConfig(studioHostConfig);
  const id=await agentStorageId(config.parentOrigin,config.accountId,config.projectId);
  window.agentStorageLease=await acquireAgentStorage(id);
  return id;
});
</script>`;
};
const streams={requests:0,closed:0,chunks:0};
let rejectedHostEngineRequests=0;
let accessRevoked=false,authorizedReads=0;
const privateRoute=createAgentHostRoute({authorize:async(req,id)=>{
  if(id!==ownedLaunch?.id || accessRevoked || !req.headers.cookie?.split(';').some(item=>item.trim()==='studio-test-session=owner'))return null;
  authorizedReads++;return {accountId:'test-account',projectId:'owned',generation:ownedData.config.generation};
},getLaunch:async id=>launchStore.get(id)});
const pattern=/<script\s+async\s+src=["']?dora-player-runtime\.js["']?\s*>/;
assert.ok(pattern.test(html));
const server=createServer(async(req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
  res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
  try{
    if(await privateRoute(req,res))return;
    const launchPrefix='/agent-host/'+ownedLaunch?.id;
    const staticPath=req.url.startsWith(launchPrefix+'/')?req.url.slice(launchPrefix.length):req.url;
    if(req.url==='/favicon.ico'){res.writeHead(204);res.end();return;}
    if(req.url==='/broken/index.html'){res.setHeader('Content-Type','text/html');res.end(await readFile('dist/agent-host/index.html'));return;}
    if(req.url==='/broken/page.js'){res.setHeader('Content-Type','text/javascript');res.end(await readFile('dist/agent-host/page.js'));return;}
    if(req.url==='/broken/host-config.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(hostData('owned').config));return;}
    if(req.url==='/broken/dora-web-features.json'){res.setHeader('Content-Type','application/json');res.end('{"studioAgentHost":false}');return;}
    if(req.url==='/broken/dora-player-runtime.js'){rejectedHostEngineRequests++;throw Error('Must not load a non-Agent engine');}
    if(staticPath==='/index.html'){res.setHeader('Content-Type','text/html');res.end(await readFile('dist/agent-host/index.html'));return;}
    if(staticPath==='/page.js'){res.setHeader('Content-Type','text/javascript');res.end(await readFile('dist/agent-host/page.js'));return;}
    if(req.url==='/lease-check'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><body></body>');return;}
    if(req.url==='/stream-model'){
      let body='';for await(const chunk of req)body+=chunk;
      const request=JSON.parse(body);assert.equal(request.model,'fixture');assert.equal(request.stream,true);
      streams.requests++;
      res.setHeader('Content-Type','text/event-stream');res.setHeader('Cache-Control','no-cache');
      const send=()=>{streams.chunks++;res.write('data: '+JSON.stringify({id:'stream-test',choices:[{index:0,delta:{content:'Still generating. '},finish_reason:null}]})+'\n\n');};
      send();const timer=setInterval(send,100);
      res.on('close',()=>{clearInterval(timer);streams.closed++;});return;
    }
    if(req.url==='/storage.js'||req.url==='/bootstrap.js'){res.setHeader('Content-Type','text/javascript');res.end(hostSupport);return;}
    if(req.url==='/adapter.js'){res.setHeader('Content-Type','text/javascript');res.end(adapterBundle.outputFiles[0].text);return;}
    if(req.url==='/lifecycle.js'){res.setHeader('Content-Type','text/javascript');res.end(lifecycleBundle.outputFiles[0].text);return;}
    if(['/','/restore','/active','/active-restore','/isolated','/capture'].includes(req.url)){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html.replace(pattern,match=>injection(req.url==='/'?'normal':req.url.slice(1))+match));return;}
    const file=resolve(root,'.'+new URL(staticPath,'http://local').pathname);
    if(!file.startsWith(root+sep))throw Error('outside');
    res.setHeader('Content-Type',({'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[extname(file)]||'application/octet-stream');
    if(file===resolve(root,'dora-player-runtime.js')){
      res.end("self.addEventListener('error',event=>{if(event.error?.stack)console.error(event.error.stack);});\n"+await readFile(file,'utf8'));return;
    }
    res.end(await readFile(file));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
let launchRoute,revokeRoute;
const parentServer=createServer(async(req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
  if(launchRoute && await launchRoute(req,res))return;
  if(revokeRoute && await revokeRoute(req,res))return;
  if(req.url==='/launch.js'){res.setHeader('Content-Type','text/javascript');res.end(launchBundle.outputFiles[0].text);return;}
  if(req.url==='/adapter.js'){res.setHeader('Content-Type','text/javascript');res.end(adapterBundle.outputFiles[0].text);return;}
  if(req.url==='/empty'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/style.css"></head><body><div class="workbench show-agent"><section class="work-pane"><p>真实 Agent 保存关闭验证</p></section><div id="panel" style="display:contents"></div></div></body></html>');return;}
  if(req.url==='/panel.js'){res.setHeader('Content-Type','text/javascript');res.end(panelBundle.outputFiles[0].text);return;}
  if(req.url==='/style.css'){res.setHeader('Content-Type','text/css');res.end(panelCss);return;}
  if(req.url==='/dora-symbol.svg'){res.setHeader('Content-Type','image/svg+xml');res.end(await readFile('apps/web/dist/dora-symbol.svg'));return;}
  if(req.url==='/app-test.js'){res.setHeader('Content-Type','text/javascript');res.end(appBundle.outputFiles[0].text);return;}
  if(req.url==='/app-test'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/style.css"></head><body><div id="root"></div></body></html>');return;}
  if(['/compiler/','/teal/','/declarations/'].some(prefix=>req.url.startsWith(prefix))){
    const path=resolve('apps/web/dist','.'+new URL(req.url,'http://localhost').pathname);
    if(!['compiler','teal','declarations'].some(directory=>path.startsWith(resolve('apps/web/dist',directory)+sep))){res.writeHead(404);res.end();return;}
    try{res.setHeader('Content-Type',path.endsWith('.json')?'application/json':'text/javascript');res.end(await readFile(path));}catch{res.writeHead(404);res.end();}return;
  }
  res.setHeader('Content-Type','text/html');
  res.end(`<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/style.css"></head><body><div class="workbench show-agent"><section class="work-pane"><p>真实 Agent 会话连接测试 · 非生成入口</p><iframe id="agent" allow="cross-origin-isolated" src="http://127.0.0.1:${server.address().port}/"></iframe></section><div id="panel" style="display:contents"></div></div></body></html>`);
});
await new Promise(done=>parentServer.listen(0,'127.0.0.1',done));
launchRoute=createAgentLaunchRoute({studioOrigin:`http://127.0.0.1:${parentServer.address().port}`,hostOrigin:`http://127.0.0.1:${server.address().port}`,engineVersion:'1.9.2',
  authorizeProject:async(req,projectId)=>projectId==='owned' && !accessRevoked && req.headers.cookie?.split(';').some(item=>item.trim()==='studio-test-session=owner')?{accountId:'test-account',projectId,title:ownedTitle}:null,
  createSnapshot:async(config,options)=>{ownedData=await createAgentHostSnapshot(config,options);return ownedData;},
  store:{put:snapshot=>{ownedLaunch=launchStore.put(snapshot);return ownedLaunch;}}});
revokeRoute=createAgentLaunchRevokeRoute({studioOrigin:`http://127.0.0.1:${parentServer.address().port}`,store:launchStore,
  authorizeProject:async(req,projectId)=>projectId==='owned' && !accessRevoked && req.headers.cookie?.split(';').some(item=>item.trim()==='studio-test-session=owner')?{accountId:'test-account',projectId}:null});
const playerRoot=resolve('../build/studio-runtime');
const playerMetadata=JSON.parse(await readFile(resolve(playerRoot,'studio-runtime.json'),'utf8'));
const gamePlayer=createServer(async(req,res)=>{
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.setHeader('Cross-Origin-Resource-Policy','cross-origin');
  try{
    const path=resolve(playerRoot,'.'+new URL(req.url,'http://localhost').pathname);
    if(!path.startsWith(playerRoot+sep))throw Error('outside');
    res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json'})[extname(path)]||'application/octet-stream');
    res.end(await readFile(path));
  }catch{res.writeHead(404);res.end();}
});
await new Promise(done=>gamePlayer.listen(0,'127.0.0.1',done));
let browser,initialPage,diagnosticPage,formalAppPage;const report={errors:[],console:[]};
try{
  browser=await chromium.launch({headless:true,executablePath:process.env.STUDIO_CHROME_PATH,args:['--enable-unsafe-swiftshader']});
  const context=await browser.newContext();
  const page=await context.newPage();initialPage=page;
  let failPage;
  const pageFailure=new Promise((_,reject)=>{failPage=reject;});
  pageFailure.catch(()=>{});
  page.on('pageerror',error=>{report.errors.push(error.stack??error.message);failPage(error);});
  page.on('console',message=>{report.console.push({type:message.type(),text:message.text()});if(message.type()==='error')console.error(message.text());});
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await Promise.race([pageFailure,page.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='complete'),null,{timeout:60000})]);
  await page.evaluate(()=>{
    Module.ccall('dora_web_agent_request',null,['string'],[JSON.stringify({operation:'eval',sessionId:1,requestId:'rejected',code:'error("must not execute")'})]);
    Module.ccall('dora_web_agent_request',null,['string'],[JSON.stringify({operation:'snapshot',sessionId:1,requestId:'fresh-snapshot'})]);
    Module.ccall('dora_web_agent_request',null,['string'],[JSON.stringify({operation:'quiesce',sessionId:1,requestId:'quiesce-snapshot'})]);
  });
  await page.waitForFunction(()=>window.agentCallbackEvents.some(event=>event.requestId==='fresh-snapshot'),null,{timeout:10000});
  await page.waitForFunction(()=>window.agentCallbackEvents.some(event=>event.requestId==='quiesce-snapshot'),null,{timeout:10000});
  report.events=await page.evaluate(()=>window.agentCallbackEvents);
  const quiescent=JSON.parse(report.events.find(event=>event.requestId==='quiesce-snapshot').payload).studioQuiescence;
  assert.equal(quiescent.success,true);assert.equal(quiescent.quiescent,true);assert.equal(quiescent.pending.length,0);
  assert.equal(streams.requests,3);
  assert.equal(streams.closed,3,'Streams must close while the first runtime page is still alive');
  assert.deepEqual(report.events.filter(event=>event.kind==='unicode'||event.kind==='complete'),[{kind:'unicode',value:'中文回调'},{kind:'complete'}]);
  const snapshot=report.events.find(event=>event.kind==='snapshot');
  const patches=report.events.filter(event=>event.kind==='patch');
  assert.equal(JSON.parse(snapshot.payload).session.title,'原 Agent 宿主桥接');
  assert.equal(patches.length,1,'closing the Lua bridge must unsubscribe before the second mode change');
  assert.equal(patches[0].sequence,snapshot.sequence+1);
  assert.equal(JSON.parse(patches[0].payload).session.workMode,'plan');
  const fresh=report.events.find(event=>event.requestId==='fresh-snapshot');
  assert.equal(fresh.sequence,2);
  assert.equal(JSON.parse(fresh.payload).session.workMode,'code');
  const fileCommits=JSON.parse(fresh.payload).studioFileCommits;
  assert.equal(fileCommits.batches.length,1);
  assert.equal(fileCommits.batches[0].changes[0].path,'queued-author.lua');
  assert.equal(fileCommits.overflowed,false);
  assert.equal(fileCommits.reconciliationRequired,true);
  report.nativeFileCommitQueuePassed=true;
  const captureContext=await browser.newContext();
  try{
    const capturePage=await captureContext.newPage();
    await capturePage.goto(`http://127.0.0.1:${server.address().port}/capture`);
    await capturePage.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='capture-ready'),null,{timeout:60000});
    report.realLifecycleCapture=await capturePage.evaluate(async()=>{
      const {installAgentWasmHost}=await import('/adapter.js');
      const sessionId=window.agentCallbackEvents.find(event=>event.kind==='capture-ready').sessionId;
      delete Module.doraStudioAgentEvent;
      const host=installAgentWasmHost(Module,{postMessage(){}},'https://studio.example',{projectId:'capture',generation:'capture-generation',sessionId,projectRoot:'/user/studio-project'});
      try{
        const result=await host.captureProject(new AbortController().signal);
        return {projectId:result.projectId,pending:result.reconciliationRequired,files:result.files.map(file=>({path:file.path,text:new TextDecoder().decode(file.bytes)}))};
      }finally{host.close();}
    });
    assert.deepEqual(report.realLifecycleCapture,{projectId:'capture',pending:true,files:[{path:'init.lua',text:'return 42'}]});
  }finally{await captureContext.close();}
  assert(report.events.some(event=>event.kind==='checkpoint-recovery-semantics-verified'));
  report.nativeCheckpointRecoverySemanticsPassed=true;
  const overflow=JSON.parse(report.events.find(event=>event.requestId==='overflow-check').payload).studioFileCommits;
  assert.equal(overflow.batches.length,32,'duplicate notification must not consume a queue slot');
  assert.equal(overflow.batches[31].checkpointId,1032);
  assert.equal(overflow.overflowed,true);
  assert.equal(overflow.reconciliationRequired,true);
  report.nativeFileCommitOverflowPassed=true;
  for(const requestId of ['byte-overflow-check','conflicting-notification-check','invalid-notification-check','oversized-notification-check']){
    const queue=JSON.parse(report.events.find(event=>event.requestId===requestId).payload).studioFileCommits;
    assert.equal(queue.batches.length,1,requestId);
    assert.equal(queue.overflowed,true,requestId);
    assert.equal(queue.reconciliationRequired,true,requestId);
    if(requestId==='conflicting-notification-check')assert.equal(queue.batches[0].changes[0].path,'first.lua');
    if(requestId==='byte-overflow-check')assert.equal(queue.batches[0].changes.length,220);
  }
  report.nativeFileCommitFailureBoundariesPassed=true;
  assert.equal(report.events.some(event=>event.requestId==='rejected'),false);
  report.snapshotRequestRoundTripPassed=true;
  report.originalSessionBridgePassed=true;
  report.adapter=await page.evaluate(async()=>{
    const {createAgentWasmSource,serveAgentSessionPort,connectAgentSessionPort}=await import('/adapter.js');
    // Release the test recorder explicitly; production ownership must never be stolen.
    delete Module.doraStudioAgentEvent;
    const source=createAgentWasmSource(Module,1);
    const commits=await source.readFileCommits(new AbortController().signal);
    if(commits.batches.length!==1 || commits.batches[0].changes[0].path!=='queued-author.lua' || !commits.reconciliationRequired)throw Error('Typed native file queue mismatch');
    const stopped=await source.quiesce(new AbortController().signal);
    if(!stopped.quiescent || stopped.pending.length)throw Error('Expected quiescent bound session');
    const {persistStoppedAgent}=await import('/lifecycle.js');
    await persistStoppedAgent(source,Module,new AbortController().signal);
    const channel=new MessageChannel();
    const binding={projectId:'wasm-test',generation:'wasm-generation',sessionId:1};
    const host=serveAgentSessionPort(channel.port1,binding,source);
    let client;
    try{
      client=await connectAgentSessionPort(channel.port2,binding,new AbortController().signal);
      const state=client.controller.getSnapshot();
      source.close();
      await new Promise((resolve,reject)=>{
        if(client.controller.getSnapshot().connection==='closed'){resolve();return;}
        const timer=setTimeout(()=>{unsubscribe();reject(Error('source close did not reach client'));},2000);
        const unsubscribe=client.controller.subscribe(()=>{
          if(client.controller.getSnapshot().connection==='closed'){clearTimeout(timer);unsubscribe();resolve();}
        });
      });
      return {title:state.state.session.title,workMode:state.state.session.workMode,connection:state.connection,closed:client.controller.getSnapshot().connection};
    }finally{client?.close();host.close();source.close();}
  });
  assert.deepEqual(report.adapter,{title:'原 Agent 宿主桥接',workMode:'code',connection:'live',closed:'closed'});
  report.wasmSourcePortRoundTripPassed=true;
  await page.evaluate(async()=>{
    Module.FS.writeFile('/user/settings/agent-barrier.txt','barrier-confirmed');
    await Module.doraSyncUserStorage({afterCurrent:true});
  });
  const storageId=await page.evaluate(()=>Module.doraStorageId);
  const leasePage=await context.newPage();
  await leasePage.goto(`http://127.0.0.1:${server.address().port}/lease-check`);
  const concurrentRejected=await leasePage.evaluate(async id=>{
    const {acquireAgentStorage}=await import('/storage.js');
    try{const lease=await acquireAgentStorage(id);await lease.release();return false;}
    catch(error){return error.message.includes('already open');}
  },storageId);
  assert.equal(concurrentRejected,true);
  await page.close();
  await leasePage.evaluate(async id=>{
    const {acquireAgentStorage}=await import('/storage.js');
    const lease=await acquireAgentStorage(id);await lease.release();await lease.release();
  },storageId);
  report.exclusiveStorageLeasePassed=true;
  await leasePage.close();
  const isolatedPage=await context.newPage();
  diagnosticPage=isolatedPage;
  isolatedPage.on('pageerror',error=>report.errors.push(error.stack??error.message));
  await isolatedPage.goto(`http://127.0.0.1:${server.address().port}/isolated`);
  await isolatedPage.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='isolated'),null,{timeout:15000});
  report.projectStorageIsolationPassed=true;
  await isolatedPage.close();
  const restoredPage=await context.newPage();
  restoredPage.on('pageerror',error=>report.errors.push(error.message));
  await restoredPage.goto(`http://127.0.0.1:${server.address().port}/restore`);
  await restoredPage.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='restored'),null,{timeout:15000});
  report.persistedSession=await restoredPage.evaluate(()=>window.agentCallbackEvents.find(event=>event.kind==='restored'));
  assert.deepEqual(report.persistedSession,{kind:'restored',main:'STOPPED',child:'STOPPED'});
  await restoredPage.close();
  const parentPage=await browser.newPage();
  report.crossOriginConsole=[];
  parentPage.on('console',message=>report.crossOriginConsole.push({type:message.type(),text:message.text()}));
  parentPage.on('pageerror',error=>report.errors.push(error.message));
  const parentOrigin=`http://127.0.0.1:${parentServer.address().port}`;
  await parentPage.goto(parentOrigin);
  const hostFrame=parentPage.frames().find(frame=>frame.parentFrame());
  assert.ok(hostFrame);
  try {
    await hostFrame.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='complete'),null,{timeout:60000});
  } catch(error) {
    report.crossOriginFailure=await hostFrame.evaluate(()=>({url:location.href,state:document.documentElement.dataset.doraState,text:document.body?.innerText,isolated:crossOriginIsolated,events:window.agentCallbackEvents}));
    throw error;
  }
  await hostFrame.evaluate(async origin=>{
    const {installAgentWasmHost}=await import('/adapter.js');
    delete Module.doraStudioAgentEvent;
    window.testFrameHost=installAgentWasmHost(Module,parent,origin,{projectId:'cross-origin-wasm',generation:'generation-1',sessionId:1});
  },parentOrigin);
  report.crossOrigin=await parentPage.evaluate(async origin=>{
    const {connectAgentFrameSession}=await import('/adapter.js');
    window.testConnection=await connectAgentFrameSession(document.querySelector('#agent'),origin,{projectId:'cross-origin-wasm',generation:'generation-1',sessionId:1},new AbortController().signal);
    const {mount}=await import('/panel.js');
    window.unmountTestPanel=mount(window.testConnection.controller,window.testConnection.canPersist?window.testConnection.persist:undefined);
    const snapshot=window.testConnection.controller.getSnapshot();
    return {title:snapshot.state.session.title,workMode:snapshot.state.session.workMode,connection:snapshot.connection};
  },`http://127.0.0.1:${server.address().port}`);
  assert.deepEqual(report.crossOrigin,{title:'原 Agent 宿主桥接',workMode:'code',connection:'live'});
  await parentPage.getByRole('button',{name:'暂停并保存',exact:true}).click();
  await parentPage.getByRole('button',{name:'已保存到本机',exact:true}).waitFor();
  assert.equal(await parentPage.getByRole('button',{name:'已保存到本机',exact:true}).isDisabled(),true);
  await parentPage.getByText('原 Agent 宿主桥接',{exact:true}).waitFor();
  await parentPage.getByText('创作模式',{exact:true}).waitFor();
  assert.equal(await parentPage.getByRole('button',{name:'发送 ↑'}).isDisabled(),true);
  assert.equal(await hostFrame.evaluate(()=>{
    window.testFrameHost.close();window.testFrameHost.close();
    return Module.doraStudioAgentEvent === undefined;
  }),true);
  await parentPage.waitForFunction(()=>window.testConnection.controller.getSnapshot().connection==='closed');
  await parentPage.getByRole('status').filter({hasText:'会话连接已关闭'}).waitFor();
  await parentPage.locator('.badge').filter({hasText:'已断开'}).waitFor();
  await mkdir('apps/web/artifacts/agent-host-callback',{recursive:true});
  await parentPage.screenshot({path:resolve('apps/web/artifacts/agent-host-callback/session-panel.png'),fullPage:true});
  await parentPage.evaluate(()=>{window.unmountTestPanel();window.testConnection.close();});
  report.realSessionPanelPassed=true;
  assert.equal(streams.closed,6,'The second runtime streams must close before its page is destroyed');
  await parentPage.close();
  report.crossOriginWasmRoundTripPassed=true;
  assert.equal(streams.requests,6,'Both runtime instances must reach the three model streams');
  assert.equal(streams.closed,6,'Cancellation must close every model stream');
  assert.ok(streams.chunks>=6);
  const activeContext=await browser.newContext();
  const activePage=await activeContext.newPage();
  activePage.on('pageerror',error=>report.errors.push(error.message));
  await activePage.goto(`http://127.0.0.1:${server.address().port}/active`);
  await activePage.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='active-ready'),null,{timeout:15000});
  report.activePersistence=await activePage.evaluate(async()=>{
    const {createAgentWasmSource}=await import('/adapter.js');
    const {persistStoppedAgent}=await import('/lifecycle.js');
    delete Module.doraStudioAgentEvent;
    const source=createAgentWasmSource(Module,1),observations=[];
    try {
      await persistStoppedAgent({quiesce:async signal=>{const state=await source.quiesce(signal);observations.push(state.pending.length);return state;}},Module,new AbortController().signal);
      const detail=JSON.parse((await source.capture(new AbortController().signal)).payload);
      return {observations,status:detail.session.currentTaskStatus};
    }finally{source.close();}
  });
  assert.equal(report.activePersistence.observations[0],2);
  assert.equal(report.activePersistence.observations.at(-1),0);
  assert.equal(report.activePersistence.status,'STOPPED');
  assert.equal(streams.requests,8);assert.equal(streams.closed,8);
  await activePage.close();
  const activeRestoredPage=await activeContext.newPage();
  activeRestoredPage.on('pageerror',error=>report.errors.push(error.message));
  await activeRestoredPage.goto(`http://127.0.0.1:${server.address().port}/active-restore`);
  await activeRestoredPage.waitForFunction(()=>window.agentCallbackEvents?.some(event=>event.kind==='active-restored'),null,{timeout:15000});
  assert.equal(streams.requests,8,'Reading restored sessions must not resend model requests');
  report.activeSessionRestorePassed=true;
  await activeRestoredPage.close();
  const ownedParent=await browser.newPage();formalAppPage=ownedParent;
  assert.equal((await ownedParent.request.post(`http://127.0.0.1:${parentServer.address().port}/api/projects/owned/agent-launch`,{headers:{Origin:`http://127.0.0.1:${parentServer.address().port}`}})).status(),403);
  assert.equal(launchStore.stats().entries,0);
  await ownedParent.context().addCookies([{name:'studio-test-session',value:'owner',url:`http://127.0.0.1:${server.address().port}`,httpOnly:true,sameSite:'Lax'}]);
  report.ownedConsole=[];
  ownedParent.on('console',message=>report.ownedConsole.push({type:message.type(),text:message.text()}));
  ownedParent.on('pageerror',error=>report.errors.push(error.message));
  await ownedParent.goto(`http://127.0.0.1:${parentServer.address().port}/empty`);
  await ownedParent.evaluate(async origin=>{
    const {startWorkspaceAgent}=await import('/launch.js');
    const startup=new AbortController();
    const binding=await startWorkspaceAgent(document.body,'owned',origin,startup.signal);
    try {
      startup.abort(); // Startup cancellation must not force-close a handed-off session.
      if(binding.controller.closed)throw Error('Startup abort destroyed the active binding');
      if(binding.controller.state.session.projectRoot!=='/user/studio-project')throw Error('Author project overlaps the privileged host');
      const title=binding.controller.state.session.title;
      const frame=document.querySelector('iframe');
      const hidden=frame.hidden,ariaHidden=frame.getAttribute('aria-hidden'),tabIndex=frame.tabIndex;
      const {mount}=await import('/panel.js');
      const unmount=mount(binding.controller,undefined,binding.retirement);
      window.ownedRetirement={binding,title,hidden,ariaHidden,tabIndex,unmount};
    }catch(error){await binding.retirement.run();throw error;}
  },`http://127.0.0.1:${server.address().port}`);
  assert.equal(launchStore.stats().entries,1);
  await ownedParent.evaluate(async()=>{
    const {binding}=window.ownedRetirement;
    if(!binding.syncProject)throw Error('Production author synchronization capability missing');
    const snapshot={version:1,projectId:'owned',revision:1,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'-- cross-origin author source'},{path:'Resources/sync.bin',kind:'binary',bytes:new Uint8Array([9,0,255])}]};
    await binding.syncProject(snapshot,new AbortController().signal);
    await binding.syncProject(snapshot,new AbortController().signal);
    const changed=structuredClone(snapshot);changed.revision=2;changed.files[0].text='-- changed author source';
    await binding.syncProject(changed,new AbortController().signal);
    let refused=false;try{await binding.syncProject(snapshot,new AbortController().signal);}catch{refused=true;}
    if(!refused)throw Error('Stale author revision was accepted');
    await binding.syncProject({...snapshot,revision:3},new AbortController().signal);
  });
  const authorFrame=ownedParent.frames().find(frame=>frame!==ownedParent.mainFrame());
  assert.deepEqual(await authorFrame.evaluate(()=>({source:Module.FS.readFile('/user/studio-project/init.lua',{encoding:'utf8'}),bytes:[...Module.FS.readFile('/user/studio-project/Resources/sync.bin')]})),{source:'-- cross-origin author source',bytes:[9,0,255]});
  report.crossOriginAuthorSynchronizationPassed=true;
  report.workspaceCapture=await ownedParent.evaluate(async()=>{
    const captured=await window.ownedRetirement.binding.captureProject(new AbortController().signal);
    return {projectId:captured.projectId,pending:captured.reconciliationRequired,files:captured.files.map(file=>({path:file.path,bytes:[...file.bytes]}))};
  });
  assert.equal(report.workspaceCapture.projectId,'owned');
  assert.equal(report.workspaceCapture.pending,true);
  assert.deepEqual(report.workspaceCapture.files.find(file=>file.path==='Resources/sync.bin').bytes,[9,0,255]);
  assert.equal(new TextDecoder().decode(new Uint8Array(report.workspaceCapture.files.find(file=>file.path==='init.lua').bytes)),'-- cross-origin author source');
  report.workspaceCapturePassed=true;
  report.realAuthorInstallation=await authorFrame.evaluate(async()=>{
    const {installAgentProjectSnapshot:install,writeAgentProjectBaseline,readInstalledAgentFiles:readFiles}=await import('/adapter.js');
    const fs=Module.FS,root='/user/studio-project';
    fs.mkdirTree(root+'/.agent');fs.writeFile(root+'/.agent/install-test.txt','session retained');
    fs.writeFile(root+'/old.txt','old author version');
    const trusted=fs.readFile('/game/init.lua',{encoding:'utf8'});
    const snapshot={version:1,projectId:'owned',revision:7,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'error("AUTHOR_MUST_NOT_RUN")'},{path:'Resources/test.bin',kind:'binary',bytes:new Uint8Array([0,255,128])}]};
    const failureFS=Object.create(fs);
    failureFS.rename=(from,to)=>{if(from.includes('.studio-author-stage-')&&to===root)throw Error('injected exchange failure');return fs.rename(from,to);};
    let rejected=false;try{install(failureFS,snapshot);}catch{rejected=true;}
    if(!rejected || fs.readFile(root+'/old.txt',{encoding:'utf8'})!=='old author version')throw Error('Real filesystem rollback failed');
    const installed=install(fs,snapshot);
    const captured=readFiles(fs);
    if(captured.length!==2 || captured.some(file=>file.path.startsWith('.agent/')))throw Error('Captured private session data');
    const binary=captured.find(file=>file.path==='Resources/test.bin');
    if(!binary || String([...binary.bytes])!=='0,255,128')throw Error('Captured binary mismatch');
    binary.bytes[0]=99;
    if(fs.readFile(root+'/Resources/test.bin')[0]!==0)throw Error('Capture aliases runtime storage');
    fs.writeFile(root+'/temporary.lua','return 0');
    if(!readFiles(fs).some(file=>file.path==='temporary.lua'))throw Error('Capture missed new file');
    fs.unlink(root+'/temporary.lua');
    if(readFiles(fs).some(file=>file.path==='temporary.lua'))throw Error('Capture retained deleted file');
    fs.symlink('/game',root+'/forbidden-link');
    let linkRejected=false;try{readFiles(fs);}catch{linkRejected=true;}finally{fs.unlink(root+'/forbidden-link');}
    if(!linkRejected)throw Error('Capture followed a host link');
    await writeAgentProjectBaseline(fs,snapshot,new AbortController().signal);
    return {installed,rollback:true,bytes:[...fs.readFile(root+'/Resources/test.bin')],session:fs.readFile(root+'/.agent/install-test.txt',{encoding:'utf8'}),hostUnchanged:fs.readFile('/game/init.lua',{encoding:'utf8'})===trusted,oldRemoved:!fs.analyzePath(root+'/old.txt').exists};
  });
  assert.deepEqual(report.realAuthorInstallation,{installed:{projectId:'owned',revision:7,cleanupPending:false},rollback:true,bytes:[0,255,128],session:'session retained',hostUnchanged:true,oldRemoved:true});
  report.realAgentCurrentFilesCapturePassed=true;
  await ownedParent.getByRole('button',{name:'保存并关闭 Agent',exact:true}).click();
  await ownedParent.getByRole('button',{name:'Agent 已关闭',exact:true}).waitFor();
  assert.equal(await ownedParent.getByRole('button',{name:'Agent 已关闭',exact:true}).isDisabled(),true);
  report.ownedHiddenHost=await ownedParent.evaluate(()=>{
    const {binding,title,hidden,ariaHidden,tabIndex,unmount}=window.ownedRetirement;
    if(binding.retirement.getSnapshot().phase!=='closed')throw Error('Retirement was not confirmed');
    const result={title,hidden,ariaHidden,tabIndex,removed:document.querySelector('iframe')===null,closed:binding.controller.closed};
    unmount();delete window.ownedRetirement;return result;
  });
  report.workspaceAgentStartupPassed=true;
  report.retirementSidebarClickPassed=true;
  const privateBase=`http://127.0.0.1:${server.address().port}/agent-host/${ownedLaunch.id}/`;
  report.browserLaunchCreationPassed=true;
  assert.deepEqual(launchStore.stats(),{entries:0,bytes:0});
  report.coordinatedRetirementPassed=true;
  // The Agent frame must remain frame-active; its App container is transparent,
  // not display:none/hidden, so the original Agent event loop keeps ticking.
  assert.deepEqual(report.ownedHiddenHost,{title:ownedTitle,hidden:false,ariaHidden:'true',tabIndex:-1,removed:true,closed:true});
  assert.equal(streams.requests,8);assert.equal(streams.closed,8);
  report.failedHost=await ownedParent.evaluate(async({origin,generation})=>{
    const {mountAgentHostFrame}=await import('/adapter.js');
    const owner=mountAgentHostFrame(document.body,{url:origin+'/broken/index.html',projectId:'owned',generation});
    let message='';try{await owner.ready;}catch(error){message=error.message;}finally{owner.close();}
    return {message,removed:document.querySelector('iframe')===null};
  },{origin:`http://127.0.0.1:${server.address().port}`,generation:ownedData.config.generation});
  assert.deepEqual(report.failedHost,{message:'Agent host initialization failed',removed:true});
  assert.equal(rejectedHostEngineRequests,0);
  assert.ok(authorizedReads>5,'Startup must authorize config, manifest and library reads');
  accessRevoked=true;
  for(const path of ['host-config.json','host-manifest.json','host-files/Agent/Session.lua'])assert.equal((await ownedParent.request.get(privateBase+path)).status(),403);
  report.privateResourceAuthorization={authorizedReads,revocationDenied:true};
  accessRevoked=false;
  await ownedParent.evaluate(async({url,origin})=>{
    const {revokeAgentLaunch}=await import('/launch.js');
    await revokeAgentLaunch({projectId:'owned',url},origin,new AbortController().signal);
  },{url:privateBase+'index.html',origin:`http://127.0.0.1:${server.address().port}`});
  for(const path of ['host-config.json','host-manifest.json','host-files/Agent/Session.lua'])assert.equal((await ownedParent.request.get(privateBase+path)).status(),404);
  assert.deepEqual(launchStore.stats(),{entries:0,bytes:0});
  report.launchStoreRevocationPassed=true;
  // Exercise production startup failure with real creation/revocation APIs.
  // Only the engine capability response is fault-injected.
  await ownedParent.route('**/dora-web-features.json',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({studioAgentHost:false})}));
  report.workspaceStartupFailure=await ownedParent.evaluate(async origin=>{
    const {startWorkspaceAgent}=await import('/launch.js');
    try{await startWorkspaceAgent(document.body,'owned',origin,new AbortController().signal);throw Error('Expected startup failure');}
    catch(error){return {message:error.message,cleanupPending:error.cleanupPending,removed:document.querySelector('iframe')===null};}
  },`http://127.0.0.1:${server.address().port}`);
  assert.deepEqual(report.workspaceStartupFailure,{message:'Agent 启动失败，启动实例已清理。',cleanupPending:false,removed:true});
  assert.deepEqual(launchStore.stats(),{entries:0,bytes:0});
  await ownedParent.unroute('**/dora-web-features.json');
  await ownedParent.goto(`http://127.0.0.1:${parentServer.address().port}/app-test`);
  await ownedParent.evaluate(async config=>{const {mount}=await import('/app-test.js');await mount(config.origin,config.player);},{origin:`http://127.0.0.1:${server.address().port}`,player:{url:`http://127.0.0.1:${gamePlayer.address().port}/index.html`,engineBuild:playerMetadata.engineBuild}});
  await ownedParent.locator('.project-link').filter({hasText:'Alpha'}).click();
  await ownedParent.getByRole('button',{name:'Dora Agent',exact:true}).click();
  await ownedParent.getByText(ownedTitle,{exact:true}).waitFor();
  const restoredAuthor=await ownedParent.frames().find(frame=>frame!==ownedParent.mainFrame()).evaluate(()=>({
    bytes:[...Module.FS.readFile('/user/studio-project/Resources/test.bin')],
    source:Module.FS.readFile('/user/studio-project/init.lua',{encoding:'utf8'}),
    session:Module.FS.readFile('/user/studio-project/.agent/install-test.txt',{encoding:'utf8'}),
  }));
  assert.deepEqual(restoredAuthor,{bytes:[0,255,128],source:'-- author offline edit',session:'session retained'});
  report.authorInstallationIDBFSRestorePassed=true;
  report.persistedAuthorBaselineRestoredPassed=true;
  const activeAuthorFrame=ownedParent.frames().find(frame=>frame!==ownedParent.mainFrame());
  await ownedParent.getByRole('button',{name:'资源',exact:true}).click();
  await ownedParent.getByLabel('项目代码',{exact:true}).fill(receivedGameSource);
  await ownedParent.getByRole('button',{name:'保存项目',exact:true}).click();
  await activeAuthorFrame.waitForFunction(source=>Module.FS.readFile('/user/studio-project/init.lua',{encoding:'utf8'})===source,receivedGameSource);
  report.formalAppAutomaticAuthorSyncPassed=true;
  await ownedParent.getByText('尚未编译',{exact:true}).waitFor();
  assert.equal(await ownedParent.locator('.runtime-surface iframe').count(),0);
  report.formalAppWritebackNoExtraCompilePlayPassed=true;
  await ownedParent.getByRole('button',{name:/编译项目/}).click();
  await ownedParent.getByText(/编译成功 · 2 个产物文件/).waitFor({timeout:30000});
  report.formalAppExplicitCompilePassed=true;
  await ownedParent.getByRole('button',{name:'运行游戏',exact:true}).click();
  await ownedParent.getByText('正在运行',{exact:true}).waitFor({timeout:30000});
  assert.equal(await ownedParent.locator('.runtime-surface iframe').count(),1);
  report.formalAppExplicitPlayPassed=true;
  await ownedParent.locator('.runtime-logs summary').click();
  await ownedParent.getByLabel('游戏运行日志').getByText(/STUDIO_WRITEBACK_GAME_READY/).waitFor();
  await ownedParent.frameLocator('.runtime-surface iframe').locator('#canvas').click();
  await ownedParent.getByLabel('游戏运行日志').getByText(/STUDIO_WRITEBACK_POINTER/).waitFor({timeout:10000});
  report.formalAppWritebackGameInputPassed=true;
  await mkdir('apps/web/artifacts/agent-host-callback',{recursive:true});
  await ownedParent.screenshot({path:'apps/web/artifacts/agent-host-callback/auto-play.png',fullPage:true});
  await ownedParent.getByRole('button',{name:'资源',exact:true}).click();
  assert.equal(await ownedParent.getByLabel('项目代码',{exact:true}).inputValue(),receivedGameSource);
  const receivedAuthor=await ownedParent.evaluate(async()=>{
    const {LocalWorkspace}=await import('/app-test.js');
    const store=await LocalWorkspace.open();
    try{
      const saved=await store.load('owned'),checkpoint=await store.loadCheckpoint('owned',8);
      return {revision:saved.snapshot.revision,prior:checkpoint.snapshot.files.find(file=>file.path==='init.lua').text};
    }finally{store.close();}
  });
  assert.deepEqual(receivedAuthor,{revision:9,prior:'-- author offline edit'});
  await activeAuthorFrame.evaluate(()=>Module.FS.writeFile('/user/studio-project/init.lua','-- unreconciled Agent edit'));
  await ownedParent.getByLabel('项目代码',{exact:true}).fill('-- second author draft');
  await ownedParent.getByRole('button',{name:'保存项目',exact:true}).click();
  await ownedParent.getByRole('alert').filter({hasText:'Agent 自动同步失败'}).waitFor();
  assert.equal(await ownedParent.getByLabel('项目代码',{exact:true}).inputValue(),'-- second author draft');
  assert.equal(await activeAuthorFrame.evaluate(()=>Module.FS.readFile('/user/studio-project/init.lua',{encoding:'utf8'})),'-- unreconciled Agent edit');
  report.formalAppAuthorSyncAndConflictPassed=true;
  assert.equal(launchStore.stats().entries,1);
  assert.equal(await ownedParent.locator('iframe').count(),1);
  await ownedParent.locator('.project-link').filter({hasText:'Beta'}).click();
  await ownedParent.getByRole('heading',{name:'Beta',exact:true}).waitFor();
  assert.equal(await ownedParent.locator('iframe').count(),0);
  assert.equal(await ownedParent.getByText(ownedTitle,{exact:true}).count(),0);
  assert.deepEqual(launchStore.stats(),{entries:0,bytes:0});
  report.formalAppConnectAndSwitchPassed=true;
  await ownedParent.close();
  report.streamingCancellation={...streams};
  assert.deepEqual(report.errors,[]);report.passed=true;
}finally{
  if(initialPage){try{report.initialPageEvents=await initialPage.evaluate(()=>({count:window.agentCallbackEvents?.length??0,last:window.agentCallbackEvents?.slice(-20)??[]}));}catch{report.initialPageEvents={unavailable:true};}}
  if(diagnosticPage){try{report.diagnosticPageEvents=await diagnosticPage.evaluate(()=>({count:window.agentCallbackEvents?.length??0,last:window.agentCallbackEvents?.slice(-20)??[]}));}catch{report.diagnosticPageEvents={unavailable:true};}}
  if(formalAppPage){try{report.formalAppPageState=await formalAppPage.evaluate(()=>({text:document.body.innerText.slice(-3000),iframes:document.querySelectorAll('iframe').length}));}catch{report.formalAppPageState={unavailable:true};}}
  gamePlayer.closeAllConnections();await new Promise(done=>gamePlayer.close(done));
  await browser?.close();await new Promise(done=>server.close(done));await new Promise(done=>parentServer.close(done));
  await mkdir('apps/web/artifacts/agent-host-callback',{recursive:true});
  await writeFile('apps/web/artifacts/agent-host-callback/result.json',JSON.stringify(report,null,2));
}
console.log(JSON.stringify(report));
