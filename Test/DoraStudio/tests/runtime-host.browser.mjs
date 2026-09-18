import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, readdir } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { createRequire } from 'node:module';
import { build } from 'esbuild';
import { isBoundedCapturePNG } from '../packages/contracts/dist/index.js';
import {compileAgentCommand} from './helpers/compile-agent-command.mjs';
const require = createRequire(import.meta.url);
const browserLabel = process.env.STUDIO_BROWSER_LABEL || '';
assert.match(browserLabel, /^[a-z0-9-]*$/);
const testTeal = process.env.STUDIO_TEST_TEAL === '1';
const testCommandPreview = process.env.STUDIO_TEST_COMMAND_PREVIEW === '1';
const testFullAgent = process.env.STUDIO_TEST_FULL_AGENT === '1';
const testAgentSession = process.env.STUDIO_TEST_AGENT_SESSION === '1';
const testAgentPrompt = process.env.STUDIO_TEST_AGENT_PROMPT === '1';
const testAgentTool = process.env.STUDIO_TEST_AGENT_TOOL === '1';
const testAgentPlay = process.env.STUDIO_TEST_AGENT_PLAY === '1';
assert.ok(!testAgentPlay || testAgentTool);
const agentCreatedSource=testAgentPlay ? 'local Dora=require("Dora"); local node=Dora.DrawNode(); node:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xff4cc38a)); Dora.Director.entry:addChild(node)' : 'print("STUDIO_AGENT_CREATED_GAME")';
assert.ok(!testAgentTool || testAgentPrompt);
assert.ok(!testAgentPrompt || testAgentSession);
assert.ok(!testAgentSession || testFullAgent);
const testGeneratedCommand = process.env.STUDIO_TEST_GENERATED_COMMAND === '1' || testFullAgent;
const testCommandCancel = process.env.STUDIO_TEST_COMMAND_CANCEL === '1';
assert.ok(!testCommandCancel || testCommandPreview, 'Cancellation fixture requires command preview');
const testCommandExecute = process.env.STUDIO_TEST_COMMAND_EXECUTE === '1' || testCommandPreview;
const testCommandModule = process.env.STUDIO_TEST_COMMAND_MODULE === '1' || testCommandExecute || testFullAgent;
const commandProbe = `local reportPrint = print
${testAgentPlay ? 'require("Dora").Director:endGameCapture()' : ''}
local command = require("Agent.Tool.Command")
assert(type(command.executeCommand) == "function")
print("STUDIO_COMMAND_MODULE_LOADED")
${testFullAgent ? `local agent = require("Agent.DoraAgent")
assert(type(agent.runCodingAgent) == "function")
local session = require("Agent.Session")
assert(type(session) == "table")
print("STUDIO_FULL_AGENT_LOADED")` : ''}
${testAgentSession ? `local sessions = require("Agent.Session")
local created = sessions.createSession("/game", "Studio session " .. tostring(math.random(1,1000000000)))
assert(created.success, created.message)
assert(created.session.id > 0)
local loaded = sessions.getSession(created.session.id)
assert(loaded.success, loaded.message)
local previousReplies=0
for _, message in ipairs(loaded.messages) do
  if message.role=="assistant" and message.content:find("Fixture response complete.",1,true) then previousReplies=previousReplies+1 end
end
print("STUDIO_AGENT_PREVIOUS_REPLIES",previousReplies)
local reused=sessions.createSession("/game", "Must reuse existing main session")
assert(reused.success and reused.session.id == created.session.id)
local child=sessions.createSubSession(created.session.id,"Studio child")
assert(child.success,child.message)
assert(child.session.parentSessionId == created.session.id and child.session.rootSessionId == created.session.id)
assert(child.session.kind == "sub" and child.session.id ~= created.session.id)
local childRead=sessions.getSession(child.session.id)
assert(childRead.success,childRead.message)
print("STUDIO_AGENT_SESSION_CREATED",created.session.id)
print("STUDIO_AGENT_CHILD_ID",child.session.id)
print("STUDIO_AGENT_SESSION_TITLE",created.session.title)
${testAgentPrompt ? `local patchCount=0
local eventsModule=require("Agent.Runtime.SessionEvents")
local unsubscribe=eventsModule.subscribeSessionPatches(created.session.id,function(payload,sequence)
  local data=require("Agent.Utils").safeJsonDecode(payload)
  assert(data.name=="AgentSessionPatch" and data.sessionId==created.session.id)
  patchCount=patchCount+1
  reportPrint("STUDIO_SESSION_PATCH_JSON",payload)
  reportPrint("STUDIO_SESSION_SOURCE_EVENT",require("Agent.Utils").safeJsonEncode({payload=payload,sequence=sequence}))
end)
local sent=sessions.sendPrompt(created.session.id,"Reply with a brief completion report; do not modify files.",nil,"code",nil,{
url="STUDIO_LOCAL_MODEL_URL",model="fixture",apiKey="local-test-only",contextWindow=64000,temperature=0,maxTokens=512,
supportsFunctionCalling=true,customOptions={auxiliaryOptions={test=true}}})
assert(sent.success,sent.message)
local initialSnapshot=eventsModule.captureSessionSnapshot(created.session.id,function()
  return require("Agent.Utils").safeJsonEncode(sessions.getSession(created.session.id))
end)
reportPrint("STUDIO_SESSION_INITIAL_JSON",initialSnapshot.payload)
reportPrint("STUDIO_SESSION_INITIAL_SEQUENCE",initialSnapshot.sequence)
print("STUDIO_AGENT_PROMPT_ACCEPTED")
require("Dora").thread(function()
  local Dora=require("Dora")
  local deadline=Dora.App.runningTime+8
  repeat
    Dora.sleep(0.1)
    local detail=sessions.getSession(created.session.id)
    if detail.session.status ~= "RUNNING" then
      assert(patchCount>0,"Session did not publish patches")
      unsubscribe()
      local previous=patchCount
      eventsModule.publishSessionPatch(created.session.id,'{}')
      assert(previous==patchCount,"Session unsubscribe failed")
      reportPrint("STUDIO_SESSION_PATCHES",patchCount)
      local found=false
      for _, message in ipairs(detail.messages) do
        if message.role=="assistant" and message.content:find("Fixture response complete.",1,true) then found=true end
      end
      reportPrint("STUDIO_AGENT_REPLY_STORED",found)
      reportPrint("STUDIO_SESSION_FINAL_JSON",require("Agent.Utils").safeJsonEncode(detail))
      reportPrint("STUDIO_AGENT_PROMPT_RESULT",detail.session.status)
      return
    end
  until Dora.App.runningTime>deadline
  reportPrint("STUDIO_AGENT_PROMPT_RESULT","TIMEOUT")
end)` : ''}` : ''}
${testCommandPreview ? `local Dora = require("Dora")
Dora.Director:endGameCapture() -- Delegate capture ownership to the original Agent tool.
local toolUI = Dora.DrawNode()
toolUI:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xffff0000))
Dora.Director.systemUI:addChild(toolUI)` : ''}
${testCommandExecute ? `local pending = command.executeCommand({workDir="/game",mode="lua",code=[[print(6 * 7)
local first = getEntryStatus().runId
local ok, message = enterEntryAsync({fileName="entry-fixture.lua"})
assert(ok, message)
assert(getEntryStatus().running and getEntryStatus().runId == first + 1)
assert(stopEntry())
assert(not getEntryStatus().running)
assert(not stopEntry())
local again, problem = enterEntryAsync({fileName="entry-fixture.lua"})
assert(again, problem)
assert(getEntryStatus().runId == first + 2)
assert(stopEntry())
assert(View.fieldOfView == 45, "projection not restored")
assert(not Director.entry.children or Director.entry.children.count == 0, "scene not cleared")
local failed, failure = enterEntryAsync({fileName="entry-failure.lua"})
assert(not failed and failure:find("STUDIO_EXPECTED_ENTRY_FAILURE", 1, true))
assert(not getEntryStatus().running)
assert(getEntryStatus().runId == first + 3)
assert(View.fieldOfView == 45)
assert(not Director.entry.children or Director.entry.children.count == 0)
local recovered, recoveryError = enterEntryAsync({fileName="entry-fixture.lua"})
assert(recovered, recoveryError)
assert(getEntryStatus().runId == first + 4)
assert(stopEntry())
print("STUDIO_ENTRY_FAILURE_RECOVERED")
${testCommandPreview ? `local preview = previewGame({entry="entry-capture.lua",captureAtSeconds={0,0.1}})
assert(preview.success, preview.message)
assert(#preview.files == 2 and #preview.frames == 2)
for _, frame in ipairs(preview.frames) do
  assert(frame.width > 0 and frame.height > 0)
  assert(Content.exist(frame.path))
end
assert(not getEntryStatus().running)
local postCapture, postCaptureError = enterEntryAsync({fileName="entry-fixture.lua"})
assert(postCapture, postCaptureError)
assert(getEntryStatus().runId == first + 6)
assert(stopEntry())
assert(Director:beginGameCapture(), "capture scope leaked after preview")
Director:endGameCapture()
print("STUDIO_ORIGINAL_PREVIEW_OK")` : ''}
print("STUDIO_ENTRY_LIFECYCLE_OK")]],taskId=0})
pending["then"](pending, function(_, result)
  ${testCommandPreview ? 'assert(toolUI.parent == Dora.Director.systemUI, "host UI was removed rather than excluded from capture")' : ''}
  print("STUDIO_COMMAND_EXECUTION_RESULT",result.success,(result.output:gsub("%c", " ")),result.message)
  ${testCommandCancel ? `local entry = require("Script.Dev.Entry")
  local started = Dora.App.runningTime
  local cancelled = command.executeCommand({workDir="/game",mode="lua",taskId=0,
    code='previewGame({entry="entry-capture.lua",captureAtSeconds={1}})',
    isCancelled=function() return entry.getCurrentEntryStatus().running and Dora.App.runningTime-started>0.05 end})
  local observed = cancelled["then"](cancelled,function(_, stopped)
    reportPrint("STUDIO_CANCEL_RESULT", stopped.success, stopped.interrupted, stopped.message)
    assert(print == reportPrint, "global print not restored after cancellation")
    assert(stopped.success == false and stopped.interrupted == true, "cancellation result missing")
    assert(not entry.getCurrentEntryStatus().running, "cancelled entry remains active")
    assert(Dora.Director:beginGameCapture(), "cancelled capture scope leaked")
    Dora.Director:endGameCapture()
    reportPrint("STUDIO_COMMAND_CANCEL_OK")
    local timed = command.executeCommand({workDir="/game",mode="lua",taskId=0,timeoutSeconds=1,
      code='previewGame({entry="entry-capture.lua",captureAtSeconds={2}})'})
    local checked = timed["then"](timed,function(_, expired)
      assert(expired.success == false and expired.phase == "timeout", "timeout result missing")
      assert(not entry.getCurrentEntryStatus().running, "timed out entry remains active")
      assert(print == reportPrint, "global print not restored after timeout")
      assert(Dora.Director:beginGameCapture(), "timeout capture scope leaked")
      Dora.Director:endGameCapture()
      local retry = command.executeCommand({workDir="/game",mode="lua",taskId=0,
        code='local ok,err=enterEntryAsync({fileName="entry-fixture.lua"}); assert(ok,err); assert(stopEntry()); print(99)'})
      local verified = retry["then"](retry,function(_, nextResult)
        assert(nextResult.success and nextResult.output:find("99",1,true), "command after timeout failed")
        reportPrint("STUDIO_COMMAND_TIMEOUT_RECOVERED")
        Dora.thread(function()
          local ok, message = entry.enterEntryAsync({fileName="/game/entry-fixture",workDir="/game",entryName="manual",runKind="file"})
          assert(ok,message)
          local manualId=entry.getCurrentEntryStatus().runId
          local unrelated=command.executeCommand({workDir="/game",mode="lua",code="print(1)",isCancelled=function() return true end})
          local protection=unrelated["then"](unrelated,function(_, result)
            assert(result.interrupted == true)
            assert(entry.getCurrentEntryStatus().running and entry.getCurrentEntryStatus().runId == manualId,"cancellation stopped unrelated game")
            assert(Dora.Director.entry.children and Dora.Director.entry.children.count>0,"unrelated scene removed")
            assert(entry.stop())
            reportPrint("STUDIO_COMMAND_OWNERSHIP_OK")
          end)
          protection["catch"](protection,function(_, message) reportPrint("STUDIO_OWNERSHIP_ASSERTION",message) end)
        end)
      end)
      verified["catch"](verified,function(_, message) reportPrint("STUDIO_TIMEOUT_ASSERTION",message) end)
    end)
    checked["catch"](checked,function(_, message) reportPrint("STUDIO_TIMEOUT_ASSERTION",message) end)
  end)
  observed["catch"](observed,function(_, message) reportPrint("STUDIO_CANCEL_ASSERTION",message) end)` : ''}
end, function(_, message)
  print("STUDIO_COMMAND_EXECUTION_REJECTED",message)
end)` : ''}
print("STUDIO_CHANNEL_GAME_READY")`;
const commandFiles=[];
if(testCommandModule) {
  async function collectAgent(dir,prefix='Agent') {
    for(const entry of await readdir(dir,{withFileTypes:true})) {
      if(entry.isDirectory()) await collectAgent(resolve(dir,entry.name),`${prefix}/${entry.name}`);
      else if(entry.name.endsWith('.lua')) commandFiles.push({path:`${prefix}/${entry.name}`,kind:'text',text:await readFile(resolve(dir,entry.name),'utf8')});
    }
  }
  await collectAgent(resolve('../Assets/Script/Lib/Agent'));
  if(testGeneratedCommand) {
    const generated=await compileAgentCommand({fullAgent:testFullAgent});
    for(const file of generated) {
      assert.ok(!file.path.startsWith('../') && !file.path.startsWith('/'));
      const index=commandFiles.findIndex(existing=>existing.path===file.path);
      if(index<0) commandFiles.push(file);else commandFiles[index]=file;
    }
  }
  if(testCommandExecute || testAgentPlay) commandFiles.push({path:'Script/Dev/Entry.lua',kind:'text',text:await readFile(resolve('packages/runtime-web/Entry.lua'),'utf8')});
  if(testAgentTool) commandFiles.push({path:'Script/Dev/WebServer.lua',kind:'text',text:'return {buildAsync=function(file) return {success=true,file=file} end}'});
  if(testCommandExecute) commandFiles.push({path:'entry-fixture.lua',kind:'text',text:'local Dora = require("Dora"); local node = Dora.Node(); Dora.Director.entry:addChild(node); Dora.View.fieldOfView = 60; return function() print("STUDIO_ENTRY_STARTED") end'});
  if(testCommandExecute) commandFiles.push({path:'entry-failure.lua',kind:'text',text:'local Dora = require("Dora"); Dora.Director.entry:addChild(Dora.Node()); Dora.View.fieldOfView = 70; error("STUDIO_EXPECTED_ENTRY_FAILURE")'});
  if(testCommandPreview) commandFiles.push({path:'entry-capture.lua',kind:'text',text:'local Dora = require("Dora"); local node = Dora.DrawNode(); node:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xff4cc38a)); Dora.Director.entry:addChild(node)'});
}
const testCapture = process.env.STUDIO_TEST_CAPTURE === '1';
const testCaptureRequest = process.env.STUDIO_TEST_CAPTURE_REQUEST === '1';
const testCapturePartial = process.env.STUDIO_TEST_CAPTURE_PARTIAL === '1';
assert.ok(!testCapturePartial || testCaptureRequest);
assert.ok(!(testTeal && testCapture), 'Select one language/capture fixture');
const suffix = (browserLabel ? `-${browserLabel}` : '') + (testTeal ? '-teal' : '') + (testCapture ? '-capture' : '') + (testCaptureRequest ? '-capture-request' : '') + (testCapturePartial ? '-partial' : '') + (testCommandModule ? '-command-module' : '') + (testCommandExecute ? '-execute' : '') + (testCommandPreview ? '-preview' : '');
const requestedCaptureSource = `local Dora = require("Dora")
local node = Dora.DrawNode()
node:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xff4cc38a))
Dora.Director.systemUI:addChild(node)
print("STUDIO_CHANNEL_GAME_READY")`;
const captureSource = `local Dora = require("Dora")
local Director = Dora.Director
Director:endGameCapture()
local tool = Dora.DrawNode()
tool:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xffff0000))
Director.systemUI:addChild(tool)
assert(Director:beginGameCapture())
local node = Dora.DrawNode()
node:drawPolygon({Dora.Vec2(-100,-100),Dora.Vec2(100,-100),Dora.Vec2(100,100),Dora.Vec2(-100,100)},Dora.Color(0xff4cc38a))
Director.entry:addChild(node)
assert(Director:captureGameAsync("/game/studio-capture.png", function(ok, time, size)
  assert(ok, "game capture failed")
  print("STUDIO_CAPTURE_READY", size.width, size.height)
  Director:endGameCapture()
end))
print("STUDIO_CHANNEL_GAME_READY")`;
const { chromium } = require(process.env.STUDIO_PLAYWRIGHT_MODULE || 'playwright');
const runtime = resolve('../build/studio-runtime');
const metadata = JSON.parse(await readFile(resolve(runtime, 'studio-runtime.json')));
const bundle = await build({ stdin:{contents:`export {RuntimeHost} from './runtime-host'; export {serializeArtifactContent} from '@dora-studio/contracts';`,resolveDir:resolve('apps/web/src'),loader:'ts'}, bundle: true, write: false,
  format: 'esm', platform: 'browser', target: 'es2022' });
const captureStorageBundle = testCaptureRequest || testAgentPrompt ? await build({stdin:{contents:`export {LocalWorkspace} from './workspace'; export {saveAgentCaptures} from './agent-captures'; export {captureAgentRunBatch} from './agent-capture-batch'; export {saveAgentFileChanges} from './agent-file-changes'; export {createAgentSessionFeed} from './agent-session-feed'; export {createAgentSessionPublisher} from './agent-session-publisher'; export {createAgentSessionState} from './agent-session-state'; export {openAgentSessionSnapshot} from './agent-session-controller';`,resolveDir:resolve('apps/web/src'),loader:'ts'},bundle:true,write:false,format:'esm',platform:'browser',target:'es2022'}) : undefined;
const tealResources = new Map();
if (testTeal) {
  const declarations = [];
  async function collect(directory, prefix = '') {
    for (const entry of await readdir(directory, {withFileTypes:true})) {
      if (entry.isDirectory()) await collect(resolve(directory, entry.name), prefix + entry.name + '/');
      else if (entry.name.endsWith('.d.tl')) declarations.push({path:prefix + entry.name,kind:'text',text:await readFile(resolve(directory, entry.name),'utf8')});
    }
  }
  await collect(resolve('../Assets/Script/Lib/Dora/en'));
  const tealBundle = await build({stdin:{contents:`export {createTealWorkerBuild} from './teal-worker-client.js'; export {compileTealProject} from './teal-project.js'; export {serializeArtifactContent} from '@dora-studio/contracts';`,resolveDir:resolve('packages/agent-contracts/dist')},bundle:true,write:false,format:'esm',platform:'browser'});
  tealResources.set('/teal.js', tealBundle.outputFiles[0].text);
  tealResources.set('/declarations.json', JSON.stringify(declarations));
  for (const name of ['worker.mjs','compiler.mjs']) tealResources.set('/' + name, await readFile(resolve('packages/agent-contracts/dist/teal', name)));
}
const report = { errors: [], logs: [], events: [], generatedCommandFromTypeScript:testGeneratedCommand, fullAgentSource:testFullAgent };
const appCode = `import { DrawNode, Director, Vec2, Color, Size } from "Dora";
const node = DrawNode();
node.size = Size(360, 180);
node.drawPolygon([Vec2(-180,-90), Vec2(180,-90), Vec2(180,90), Vec2(-180,90)], Color(0xff4cc38a));
node.onTapBegan(() => { print("STUDIO_POINTER_RECEIVED"); });
node.onKeyDown((key) => { print("STUDIO_KEY_RECEIVED", key); });
node.onKeyUp((key) => { print("STUDIO_KEY_RELEASED", key); });
Director.ui.addChild(node);
print("STUDIO_CHANNEL_GAME_READY");`;
const headers = res => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  res.setHeader('Cache-Control', 'no-store');
};
const player = createServer(async (req, res) => {
  headers(res);
  if(req.url==='/studio-test-model') {
    const chunks=[];
    for await(const chunk of req) chunks.push(chunk);
    const request=JSON.parse(Buffer.concat(chunks).toString('utf8'));
    report.localModelRequests ??= [];
    report.localModelRequests.push({method:req.method,model:request.model,stream:request.stream,messageCount:request.messages?.length});
    res.setHeader('Content-Type','text/event-stream');
    const hasEditResult=request.messages?.some(message=>message.role==='tool' && message.tool_call_id==='studio_edit_fixture');
    const hasBuildResult=request.messages?.some(message=>message.role==='tool' && message.tool_call_id==='studio_build_fixture');
    const hasPreviewResult=request.messages?.some(message=>message.role==='tool' && message.tool_call_id==='studio_preview_fixture');
    const choice=testAgentTool && !hasEditResult
      ? {index:0,delta:{tool_calls:[{index:0,id:'studio_edit_fixture',type:'function',function:{name:'edit_file',arguments:JSON.stringify({path:'agent-created.lua',old_str:'',new_str:agentCreatedSource})}}]},finish_reason:'tool_calls'}
      : testAgentTool && !hasBuildResult
      ? {index:0,delta:{tool_calls:[{index:0,id:'studio_build_fixture',type:'function',function:{name:'build',arguments:JSON.stringify({paths:['agent-created.lua']})}}]},finish_reason:'tool_calls'}
      : testAgentPlay && !hasPreviewResult
      ? {index:0,delta:{tool_calls:[{index:0,id:'studio_preview_fixture',type:'function',function:{name:'execute_command',arguments:JSON.stringify({mode:'lua',code:'local result=previewGame({entry="agent-created.lua",captureAtSeconds={0}}); assert(result.success,result.message)'})}}]},finish_reason:'tool_calls'}
      : {index:0,delta:{content:'Fixture response complete.'},finish_reason:'stop'};
    res.end('data: '+JSON.stringify({choices:[choice],usage:{prompt_tokens:1,completion_tokens:1,total_tokens:2}})+'\n\ndata: [DONE]\n\n');
    return;
  }
  try {
    const path = resolve(runtime, '.' + new URL(req.url, 'http://local').pathname);
    if (!path.startsWith(runtime + sep)) throw new Error('outside');
    res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json' })[extname(path)] || 'application/octet-stream');
    res.end(await readFile(path));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => player.listen(0, '127.0.0.1', resolve));
const runtimeURL = `http://127.0.0.1:${player.address().port}/index.html`;
const previewBundle=await build({stdin:{contents:`import {createRoot} from 'react-dom/client';import {RuntimePreview} from './RuntimePreview';
export function mountPreview(element,artifact){const root=createRoot(element);const render=(value,id)=>root.render(<RuntimePreview artifact={value} autoRunBuildId={id} onAutoRunConsumed={()=>render(value)}/>);render(artifact,artifact.buildId);return {close:()=>root.unmount()};}`,loader:'tsx',resolveDir:resolve('apps/web/src')},bundle:true,write:false,format:'esm',platform:'browser',jsx:'automatic',define:{'import.meta.env.VITE_DORA_RUNTIME_URL':JSON.stringify(runtimeURL),'import.meta.env.VITE_DORA_ENGINE_BUILD':JSON.stringify(metadata.engineBuild)}});
const testApp = process.env.STUDIO_TEST_APP === '1';
let appServer;
if (testApp) {
  process.env.VITE_DORA_RUNTIME_URL = runtimeURL;
  process.env.VITE_DORA_ENGINE_BUILD = metadata.engineBuild;
  const { createServer: createViteServer } = await import('../apps/web/node_modules/vite/dist/node/index.js');
  appServer = await createViteServer({ root: resolve('apps/web'), server: { host: '127.0.0.1', port: 0, strictPort: false } });
  await appServer.listen();
}
const host = createServer((req, res) => {
  headers(res);
  if (tealResources.has(req.url)) { res.setHeader('Content-Type', req.url.endsWith('.json') ? 'application/json' : 'text/javascript'); res.end(tealResources.get(req.url)); return; }
  if (req.url === '/host.js') { res.setHeader('Content-Type', 'text/javascript'); res.end(bundle.outputFiles[0].text); return; }
  if (req.url === '/preview.js') {res.setHeader('Content-Type','text/javascript');res.end(previewBundle.outputFiles[0].text);return;}
  if (req.url === '/capture-storage.js' && captureStorageBundle) {res.setHeader('Content-Type','text/javascript');res.end(captureStorageBundle.outputFiles[0].text);return;}
  if (req.url === '/favicon.ico') { res.writeHead(204); res.end(); return; }
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(`<div id="runtime"></div><script type="module">
    import {RuntimeHost,serializeArtifactContent as serializeRuntimeArtifact} from '/host.js';
    window.events=[];
    window.host=new RuntimeHost(document.getElementById('runtime'), {
      runtimeURL:${JSON.stringify(runtimeURL)},engineBuild:${JSON.stringify(metadata.engineBuild)},
      onEvent:event=>window.events.push(event)});
    ${testTeal ? `
    const {createTealWorkerBuild,compileTealProject,serializeArtifactContent}=await import('/teal.js');
    const declarations=await (await fetch('/declarations.json')).json();
    const compileFile=createTealWorkerBuild(()=>new Worker('/worker.mjs',{type:'module'}),declarations);
    window.derived=await compileTealProject({version:1,projectId:'p',revision:1,entry:'main.tl',files:[
      {path:'main.tl',kind:'text',text:'local dep = require("dep")\\nprint("STUDIO_CHANNEL_GAME_READY")\\nprint("STUDIO_TEAL_VALUE", dep)'},
      {path:'dep.tl',kind:'text',text:'local value: number = 42\\nreturn value'}
    ]},compileFile);
    if(!derived.success) throw new Error(derived.message);
    const content={compilerVersion:'teal-0.15.3+dora',entry:derived.snapshot.entry,files:derived.snapshot.files,sourceMaps:{}};
    const serialized=serializeArtifactContent(content);
    ` : `const file={path:'init.lua',kind:'text',text:${JSON.stringify(testCommandModule ? commandProbe.replace('STUDIO_LOCAL_MODEL_URL',new URL('/studio-test-model',runtimeURL).href) : testCaptureRequest ? requestedCaptureSource : testCapture ? captureSource : 'print("STUDIO_CHANNEL_GAME_READY")')}};
    const content={compilerVersion:'test',entry:'init.lua',files:[file,...${JSON.stringify(commandFiles).replaceAll('<',String.fromCharCode(92)+'u003c')}],sourceMaps:{}};
    const serialized=serializeRuntimeArtifact(content);`}
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(serialized));
    window.artifact={...content,projectId:'p',revision:1,buildId:'b',
      sha256:[...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,'0')).join('')};
    ${testCaptureRequest ? `
    const {LocalWorkspace}=await import('/capture-storage.js');
    window.captureStore=await LocalWorkspace.open('runtime-capture-e2e');
    const source={version:1,projectId:'p',revision:0,entry:content.entry,files:content.files};
    await captureStore.save('Runtime capture',source,null);
    window.captureProject=await captureStore.save('Runtime capture',{...source,revision:1},0);
    ` : ''}
    window.initialRun = window.host.start(window.artifact);
  </script>`);
});
await new Promise(resolve => host.listen(0, '127.0.0.1', resolve));
let browser,appPage;
try {
  browser = await chromium.launch({ executablePath: process.env.STUDIO_CHROME_PATH, headless: true,
    args: ['--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  appPage=page;
  report.browser = await browser.version();
  report.engineBuild = metadata.engineBuild;
  page.on('pageerror', error => report.errors.push(error.message));
  page.on('response', response => { if (response.status() >= 400) report.logs.push(`HTTP ${response.status()} ${response.url()}`); });
  page.on('console', message => { report.logs.push(message.text()); if (message.type() === 'error') report.errors.push(message.text()); });
  if (testApp) {
    await page.goto(`http://127.0.0.1:${appServer.httpServer.address().port}/`);
    await page.getByRole('button',{name:/新建 \/ 导入/}).click();
    await page.getByRole('button',{name:/新建空白项目/}).click();
    await page.getByPlaceholder('给你的游戏起个名字').fill('真实试玩验收');
    await page.getByRole('button', { name: '创建并进入 Studio' }).click();
    await page.getByRole('button', { name: '资源', exact: true }).click();
    await page.getByRole('textbox', { name: '项目代码' }).fill(appCode);
    await page.getByLabel('上传资源').setInputFiles({ name: 'fixture.bin', mimeType: 'application/octet-stream', buffer: Buffer.from([0, 255, 9, 128]) });
    await page.getByText('Resources/fixture.bin', { exact: true }).waitFor();
    await page.getByLabel('上传资源').setInputFiles({ name: 'fixture.bin', mimeType: 'application/octet-stream', buffer: Buffer.from([42]) });
    await page.getByRole('alert').getByText(/素材路径冲突/).waitFor();
    assert.equal(await page.getByText('Resources/fixture.bin', { exact: true }).count(), 1);
    await page.getByRole('button', { name: '关闭错误提示' }).click();
    await page.getByLabel('上传资源').setInputFiles([
      resolve('../build/studio-main-worker/web-game-stage/Image/logo.png'),
      resolve('../build/studio-main-worker/web-game-stage/Audio/fixture.wav'),
    ]);
    await page.getByRole('button', { name: 'Resources/logo.png', exact: true }).click();
    await page.waitForFunction(() => {
      const image = document.querySelector('.resource-preview img');
      return image?.complete && image.naturalWidth > 0;
    });
    report.imagePreviewDecoded = true;
    await page.getByRole('button', { name: 'Resources/fixture.wav', exact: true }).click();
    await page.waitForFunction(() => document.querySelector('.resource-preview audio')?.readyState >= 1);
    assert.equal(await page.locator('.resource-preview audio').evaluate(audio => audio.paused), true);
    await page.locator('.resource-preview audio').evaluate(audio => audio.play());
    await page.waitForFunction(() => document.querySelector('.resource-preview audio')?.currentTime > 0);
    await page.locator('.resource-preview audio').evaluate(audio => audio.pause());
    report.audioPreviewPlayed = true;
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 ·/).waitFor({ timeout: 30000 });
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    const executionDeadline = Date.now() + 5000;
    while (!report.logs.some(log => log.includes('STUDIO_CHANNEL_GAME_READY')) && Date.now() < executionDeadline) {
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(report.logs.some(log => log.includes('STUDIO_CHANNEL_GAME_READY')), 'The compiled project must actually execute');
    const resourceFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
    assert.deepEqual(await resourceFrame.evaluate(() => [...Module.FS.readFile('/game/Resources/fixture.bin')]), [0, 255, 9, 128]);
    const canvas = page.frameLocator('iframe').locator('#canvas');
    await canvas.click();
    const inputDeadline = Date.now() + 5000;
    while (!report.logs.some(log => log.includes('STUDIO_POINTER_RECEIVED')) && Date.now() < inputDeadline) {
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(report.logs.some(log => log.includes('STUDIO_POINTER_RECEIVED')), 'Pointer input must reach the actual game');
    report.pointerReceived = true;
    await page.locator('.runtime-logs').evaluate(details => { details.open = true; });
    await page.getByLabel('游戏运行日志').getByText(/STUDIO_POINTER_RECEIVED/).waitFor();
    report.logsVisibleInApp = true;
    await page.locator('.runtime-logs').evaluate(details => { details.open = false; });
    await canvas.click();
    await page.keyboard.press('ArrowRight');
    const keyboardDeadline = Date.now() + 5000;
    while (!report.logs.some(log => log.includes('STUDIO_KEY_RELEASED\tRight')) && Date.now() < keyboardDeadline) {
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(report.logs.some(log => log.includes('STUDIO_KEY_RECEIVED\tRight')), 'Right key down must reach the actual game');
    assert.ok(report.logs.some(log => log.includes('STUDIO_KEY_RELEASED\tRight')), 'Right key up must reach the actual game');
    report.keyboardReceived = true;
    await page.getByRole('button', { name: '停止', exact: true }).click();
    const deadline = Date.now() + 5000;
    while (page.workers().length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
    assert.equal(page.workers().length, 0);
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    await mkdir(`apps/web/artifacts/runtime-app${suffix}`, { recursive: true });
    await page.screenshot({ path: `apps/web/artifacts/runtime-app${suffix}/desktop.png`, fullPage: true });
    await page.getByRole('button', { name: '保存项目', exact: true }).click();
    await page.waitForFunction(() => [...document.querySelectorAll('button')].some(button => button.textContent?.trim() === '保存项目' && button.disabled));
    await page.reload();
    await page.getByRole('navigation', { name: '本机项目' }).getByRole('button').filter({ hasText: '真实试玩验收' }).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), appCode);
    assert.equal(await page.locator('iframe').count(), 0, 'Reopening a saved project must not silently run it');
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({ timeout: 30000 });
    const previousExecutions = report.logs.filter(log => log.includes('STUDIO_CHANNEL_GAME_READY')).length;
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    const reopenDeadline = Date.now() + 5000;
    while (report.logs.filter(log => log.includes('STUDIO_CHANNEL_GAME_READY')).length <= previousExecutions && Date.now() < reopenDeadline) {
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(report.logs.filter(log => log.includes('STUDIO_CHANNEL_GAME_READY')).length > previousExecutions);
    report.savedReopenedAndExecuted = true;
    const downloadEvent = page.waitForEvent('download');
    await page.getByRole('button', { name: '下载 ZIP', exact: true }).click();
    const download = await downloadEvent;
    assert.equal(await download.failure(), null);
    await import('../../Projects/Web/web-package.js');
    const exported = await globalThis.DoraWebPackage.inspectArchive(new Uint8Array(await readFile(await download.path())));
    assert.equal(new TextDecoder().decode(exported.files.find(file => file.path === 'main.ts').data), appCode);
    assert.deepEqual([...exported.files.find(file => file.path === 'Resources/fixture.bin').data], [0, 255, 9, 128]);
    const exportedMetadata = JSON.parse(new TextDecoder().decode(exported.files.find(file => file.path === '.studio/project.json').data));
    assert.equal(exportedMetadata.entry, 'main.ts');
    report.projectZIPDownloaded = true;
    const restoredResourceFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
    assert.deepEqual(await restoredResourceFrame.evaluate(() => [...Module.FS.readFile('/game/Resources/fixture.bin')]), [0, 255, 9, 128]);
    report.uploadedResourceRestored = true;
    await page.setViewportSize({ width: 390, height: 844 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'Mobile workbench must not overflow horizontally');
    await page.getByRole('button', { name: 'Dora Agent', exact: true }).click();
    assert.equal(await page.locator('.agent-pane').isVisible(), true);
    assert.equal(await page.locator('.runtime-preview').isVisible(), true);
    assert.equal(await page.locator('.code-pane').count(), 0);
    await page.getByRole('button', { name: '资源', exact: true }).click();
    assert.equal(await page.locator('.code-pane').isVisible(), true);
    assert.equal(await page.locator('.runtime-preview').isVisible(), true);
    await page.screenshot({ path: `apps/web/artifacts/runtime-app${suffix}/mobile.png`, fullPage: true });
    report.mobileViewportPassed = true;
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.getByRole('button', { name: '资源', exact: true }).click();
    await page.getByRole('textbox', { name: '项目代码' }).fill('throw new Error("STUDIO_EXPECTED_FAILURE");');
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 ·/).waitFor({ timeout: 30000 });
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.locator('.runtime-toolbar').getByText(/Failed to initialize/).waitFor({ timeout: 55000 });
    assert.equal(await page.locator('iframe').count(), 0, 'Failed runtime must be destroyed');
    await page.locator('.runtime-logs summary').click();
    await page.getByLabel('游戏运行日志').getByText(/STUDIO_EXPECTED_FAILURE/).waitFor();
    report.scriptErrorDetailsVisible = true;
    await page.getByRole('button', { name: '资源', exact: true }).click();
    await page.getByRole('textbox', { name: '项目代码' }).fill(appCode);
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 ·/).waitFor({ timeout: 30000 });
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    report.scriptFailureRecovered = true;
    await page.getByRole('button', { name: '保存项目', exact: true }).click();
    await page.waitForFunction(() => [...document.querySelectorAll('button')].some(button => button.textContent?.trim() === '保存项目' && button.disabled));
    const projectsBeforeRestore = await page.getByRole('navigation', { name: '本机项目' }).getByRole('button').count();
    await page.getByLabel('恢复 Studio ZIP').setInputFiles(await download.path());
    await page.waitForFunction(count => document.querySelectorAll('nav[aria-label="本机项目"] button').length === count + 1, projectsBeforeRestore);
    await page.getByRole('button', { name: '资源', exact: true }).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), appCode);
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({ timeout: 30000 });
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    const restoredBackupFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
    assert.deepEqual(await restoredBackupFrame.evaluate(() => [...Module.FS.readFile('/game/Resources/fixture.bin')]), [0, 255, 9, 128]);
    report.zipRestoredAsNewPlayableProject = true;
    const luaSource = 'print("STUDIO_DORA_IMPORT_READY")';
    const encode = text => new TextEncoder().encode(text);
    const doraZIP = globalThis.DoraWebPackage.createArchive([
      { path: 'Imported/dora-package.json', data: encode(JSON.stringify({ format: 'dora-game', version: 1, entry: 'init', title: 'Dora 导入验收', engineVersion: '1.9.2' })) },
      { path: 'Imported/init.lua', data: encode(luaSource) },
      { path: 'Imported/Resources/import.bin', data: new Uint8Array([255, 0, 127]) }
    ]);
    await page.getByLabel('导入 Dora 游戏包').setInputFiles({ name: 'import-test.dora', mimeType: 'application/zip', buffer: Buffer.from(doraZIP) });
    await page.getByRole('navigation', { name: '本机项目' }).getByRole('button', { name: /Dora 导入验收/ }).waitFor();
    await page.getByRole('button', { name: '资源', exact: true }).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), luaSource);
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({ timeout: 30000 });
    await page.getByRole('button', { name: '运行游戏', exact: true }).click();
    await page.getByText('正在运行', { exact: true }).waitFor({ timeout: 55000 });
    await page.locator('.runtime-logs summary').click();
    await page.getByLabel('游戏运行日志').getByText(/STUDIO_DORA_IMPORT_READY/).waitFor();
    const importedFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
    assert.deepEqual(await importedFrame.evaluate(() => [...Module.FS.readFile('/game/Resources/import.bin')]), [255, 0, 127]);
    report.doraPackageImportedAndExecuted = true;
    const countBeforeInvalidImport = await page.getByRole('navigation', { name: '本机项目' }).getByRole('button').count();
    await page.getByLabel('导入 Dora 游戏包').setInputFiles({ name: 'broken.dora', mimeType: 'application/zip', buffer: Buffer.from('not a ZIP archive') });
    await page.getByRole('alert').waitFor();
    assert.equal(await page.getByRole('navigation', { name: '本机项目' }).getByRole('button').count(), countBeforeInvalidImport);
    await page.getByRole('button', { name: '资源', exact: true }).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), luaSource);
    report.invalidDoraImportPreservesProject = true;
    await page.getByRole('textbox', { name: '项目代码' }).fill('local value = )');
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByRole('alert').getByText(/unexpected symbol near/).waitFor({timeout:30000});
    await page.locator('.diagnostics button').filter({hasText:'lua-syntax'}).waitFor();
    assert.equal(await page.getByRole('button', {name:'运行游戏',exact:true}).isDisabled(), true);
    await page.getByRole('button', { name: '资源', exact: true }).click();
    await page.getByRole('textbox', { name: '项目代码' }).fill(luaSource);
    await page.getByRole('button', { name: '▷ 编译项目' }).click();
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({timeout:30000});
    report.luaSyntaxCheckedBeforePlay = true;
    await page.getByRole('textbox', { name: '项目代码' }).fill(luaSource + '\n-- changed');
    await page.getByRole('button', { name: '保存项目', exact: true }).click();
    await page.waitForFunction(() => [...document.querySelectorAll('button')].some(button => button.textContent?.trim() === '保存项目' && button.disabled));
    await page.getByRole('button', { name: '项目信息', exact: true }).click();
    await page.getByRole('button', { name: '查看历史记录', exact: true }).click();
    const historyRestore = page.locator('[aria-label="历史记录列表"] button').first();
    await historyRestore.click();
    await page.getByRole('dialog',{name:/恢复 .* 的内容？/}).getByRole('button',{name:'取消'}).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), luaSource + '\n-- changed');
    const unsavedCode = luaSource + '\n-- unsaved draft';
    await page.getByRole('button', { name: '关闭项目信息' }).click();
    await page.getByRole('textbox', { name: '项目代码' }).fill(unsavedCode);
    await page.getByRole('button', { name: '项目信息', exact: true }).click();
    await historyRestore.click();
    await page.getByRole('dialog',{name:'放弃未保存修改？'}).getByRole('button',{name:'取消'}).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), unsavedCode);
    await historyRestore.click();
    await page.getByRole('dialog',{name:'放弃未保存修改？'}).getByRole('button',{name:'放弃修改'}).click();
    await page.getByRole('dialog',{name:/恢复 .* 的内容？/}).getByRole('button',{name:'取消'}).click();
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), unsavedCode);
    report.checkpointCancellationPreservesDraft = true;
    await historyRestore.click();
    await page.getByRole('dialog',{name:'放弃未保存修改？'}).getByRole('button',{name:'放弃修改'}).click();
    await page.getByRole('dialog',{name:/恢复 .* 的内容？/}).getByRole('button',{name:'恢复内容'}).click();
    await page.locator('.project-info-drawer.open').waitFor({state:'hidden'});
    assert.equal(await page.getByRole('textbox', { name: '项目代码' }).inputValue(), luaSource);
    await page.getByText('尚未编译', { exact: true }).waitFor();
    report.checkpointRestoredFromUI = true;
    const tealSource = 'local dep = require("dep")\nprint("STUDIO_APP_TEAL_READY", dep)';
    const tealZIP = globalThis.DoraWebPackage.createArchive([
      {path:'dora-package.json',data:encode(JSON.stringify({format:'dora-game',version:1,entry:'init',title:'Teal 导入验收',engineVersion:'1.9.2'}))},
      {path:'init.tl',data:encode(tealSource)},
      {path:'dep.tl',data:encode('local value: number = 42\nreturn value')},
    ]);
    await page.getByLabel('导入 Dora 游戏包').setInputFiles({name:'teal.dora',mimeType:'application/zip',buffer:Buffer.from(tealZIP)});
    await page.getByRole('button', {name:'资源',exact:true}).click();
    assert.equal(await page.getByRole('textbox',{name:'项目代码'}).inputValue(),tealSource);
    await page.getByRole('button',{name:'▷ 编译项目'}).click();
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({timeout:30000});
    assert.equal(await page.getByRole('textbox',{name:'项目代码'}).inputValue(),tealSource);
    await page.getByRole('button',{name:'运行游戏',exact:true}).click();
    await page.getByText('正在运行',{exact:true}).waitFor({timeout:55000});
    await page.locator('.runtime-logs').evaluate(details => { details.open = true; });
    await page.getByLabel('游戏运行日志').getByText(/STUDIO_APP_TEAL_READY.*42/).waitFor();
    report.tealImportedCompiledAndPlayed = true;
    await page.getByRole('button',{name:'资源',exact:true}).click();
    const badTeal = 'local value: number = "wrong"\nreturn value';
    await page.getByRole('textbox',{name:'项目代码'}).fill(badTeal);
    await page.getByRole('button',{name:'▷ 编译项目'}).click();
    await page.getByRole('alert').getByText(/init\.tl/).waitFor({timeout:30000});
    assert.match(await page.getByRole('alert').innerText(), /init.tl/);
    await page.locator('.diagnostics button').first().click();
    await page.waitForFunction(() => document.querySelector('textarea')?.selectionStart === 0);
    const selection = await page.getByRole('textbox',{name:'项目代码'}).evaluate(el => ({start:el.selectionStart,end:el.selectionEnd}));
    assert.equal(selection.start, 0);
    assert.equal(selection.end, badTeal.indexOf('\n'));
    report.tealDiagnosticLocatesSource = true;
    assert.equal(await page.getByRole('textbox',{name:'项目代码'}).inputValue(),badTeal);
    assert.equal(await page.getByRole('button',{name:'运行游戏',exact:true}).isDisabled(),true);
    await page.getByRole('button',{name:'资源',exact:true}).click();
    await page.getByRole('textbox',{name:'项目代码'}).fill(tealSource);
    await page.getByRole('button',{name:'▷ 编译项目'}).click();
    // Editing creates the next draft revision, even when restoring the saved text.
    await page.getByText(/编译成功 · \d+ 个产物文件/).waitFor({timeout:30000});
    await page.getByRole('button',{name:'运行游戏',exact:true}).click();
    await page.getByText('正在运行',{exact:true}).waitFor({timeout:55000});
    await page.locator('.runtime-logs').evaluate(details => { details.open = true; });
    await page.getByLabel('游戏运行日志').getByText(/STUDIO_APP_TEAL_READY.*42/).waitFor();
    report.tealFailurePreservesDraftAndRecovers = true;
    assert.equal(report.errors.length, 0);
    report.appPassed = true;
  } else {
  await page.goto(`http://127.0.0.1:${host.address().port}/`);
  if(testCommandModule) {
    const script=await page.locator('script[type="module"]').textContent();
    await build({stdin:{contents:script,loader:'js'},write:false});
  }
  await page.waitForFunction(() => events.some(event => event.type === 'error' || (event.type === 'state' && event.state === 'running')), null, { timeout: 55000 });
  const startupError=await page.evaluate(()=>events.find(event=>event.type==='error'));
  assert.equal(startupError,undefined,startupError?.message);
  const logDeadline = Date.now() + 5000;
  while (!report.logs.some(log => log.includes('STUDIO_CHANNEL_GAME_READY')) && Date.now() < logDeadline) {
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  assert.ok(report.logs.some(log => log.includes('STUDIO_CHANNEL_GAME_READY')));
  if (testTeal) {
    await page.waitForFunction(() => events.some(event => event.type === 'log' && event.message.includes('STUDIO_TEAL_VALUE') && event.message.includes('42')), null, {timeout:5000});
    assert.equal(await page.evaluate(() => derived.snapshot.entry), 'main.lua');
    report.tealCompiledAndExecuted = true;
  }
  report.firstRun = await page.evaluate(() => events.find(event => event.state === 'running').runId);
  if(testCommandModule) {
    await page.waitForFunction(()=>events.some(event=>event.type==='log' && event.message.includes('STUDIO_COMMAND_MODULE_LOADED')));
    report.originalCommandModuleLoaded=true;
    if(testFullAgent) {
      await page.waitForFunction(()=>events.some(event=>event.type==='log' && event.message.includes('STUDIO_FULL_AGENT_LOADED')));
      report.fullAgentModulesLoaded=true;
      if(testAgentSession) {
        await page.waitForFunction(()=>events.some(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_SESSION_CREATED')));
        report.originalAgentSessionCreated=true;
        if(testAgentPrompt) {
          await page.waitForFunction(()=>events.some(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_PROMPT_RESULT')),null,{timeout:15000});
          report.agentPromptResult=await page.evaluate(()=>events.find(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_PROMPT_RESULT')).message);
          assert.match(report.agentPromptResult,/\sDONE$/);
          assert.ok(await page.evaluate(()=>events.some(event=>event.type==='log' && /STUDIO_AGENT_REPLY_STORED\s+true/.test(event.message))));
          assert.ok(report.localModelRequests?.some(request=>request.method==='POST' && request.model==='fixture' && request.stream===true && request.messageCount>0));
          report.agentReplyPersisted=true;
          const protocol=await page.evaluate(async()=>{
            const {createAgentSessionFeed,createAgentSessionPublisher}=await import('/capture-storage.js');
            const payloads=events.filter(event=>event.type==='log' && event.message.includes('STUDIO_SESSION_PATCH_JSON')).map(event=>event.message.split('STUDIO_SESSION_PATCH_JSON')[1].trim());
            const id=JSON.parse(payloads[0]).sessionId;
            const feed=createAgentSessionFeed('p','fixture-generation',id),received=[];
            const publisher=createAgentSessionPublisher('p','fixture-generation',id,event=>received.push(feed.receive(event)));
            for(const payload of payloads) publisher.publish(payload);
            publisher.close();
            return {count:payloads.length,sequence:feed.sequence,statuses:received.map(item=>item.status),needsResync:feed.needsResync};
          });
          assert.ok(protocol.count>0);assert.equal(protocol.sequence,protocol.count);
          assert.ok(protocol.statuses.every(status=>status==='accepted'));assert.equal(protocol.needsResync,false);
          report.realSessionPatchesValidated=protocol.count;
          const stateReplay=await page.evaluate(async()=>{
            const {createAgentSessionState,openAgentSessionSnapshot}=await import('/capture-storage.js');
            const read=marker=>JSON.parse(events.find(event=>event.type==='log' && event.message.includes(marker)).message.split(marker)[1].trim());
            const normalize=detail=>({...detail,checkpoints:detail.checkpoints??[],pendingQuestionnaire:detail.pendingQuestionnaire||null,spawnInfo:detail.spawnInfo??null});
            const initial=read('STUDIO_SESSION_INITIAL_JSON');
            const binding={projectId:'p',generation:'replay',sessionId:initial.session.id};
            const cursor=Number(events.find(event=>event.type==='log' && event.message.includes('STUDIO_SESSION_INITIAL_SEQUENCE')).message.split('STUDIO_SESSION_INITIAL_SEQUENCE')[1].trim());
            const controller=openAgentSessionSnapshot(binding,{version:1,...binding,sequence:cursor,payload:JSON.stringify(initial)});
            for(const event of events.filter(event=>event.type==='log' && event.message.includes('STUDIO_SESSION_SOURCE_EVENT'))) {
              const source=JSON.parse(event.message.split('STUDIO_SESSION_SOURCE_EVENT')[1].trim());
              if(source.sequence<=cursor)continue;
              const status=controller.receive({version:1,...binding,...source});
              if(status!=='updated')throw new Error('Real patch failed controller: '+status);
            }
            const state=controller.state;
            controller.close();
            const expected=createAgentSessionState(normalize(read('STUDIO_SESSION_FINAL_JSON')));
            const summarize=value=>({session:value.session,messages:[...value.messages.byId.values()].sort((a,b)=>a.id-b.id),steps:[...value.steps.byId.values()].sort((a,b)=>a.id-b.id),checkpoints:[...value.checkpoints.byId.values()].sort((a,b)=>a.id-b.id),hasActivePlan:value.hasActivePlan});
            return {actual:summarize(state),expected:summarize(expected)};
          });
          assert.deepEqual(stateReplay.actual,stateReplay.expected);
          report.realSessionCoreStateMatchesSnapshot=true;
        }
      }
    }
    report.commandModuleFiles=commandFiles.length;
    if(testCommandExecute) {
      await page.waitForFunction(()=>events.some(event=>event.type==='log' && /STUDIO_COMMAND_EXECUTION_(RESULT|REJECTED)/.test(event.message)),null,{timeout:35000});
      report.commandExecution=await page.evaluate(()=>events.find(event=>event.type==='log' && /STUDIO_COMMAND_EXECUTION_(RESULT|REJECTED)/.test(event.message)).message);
      assert.match(report.commandExecution,/STUDIO_COMMAND_EXECUTION_RESULT\s+true\s+42/);
      assert.match(report.commandExecution,/STUDIO_ENTRY_LIFECYCLE_OK/);
      assert.match(report.commandExecution,/STUDIO_ENTRY_FAILURE_RECOVERED/);
      if(testCommandPreview) assert.match(report.commandExecution,/STUDIO_ORIGINAL_PREVIEW_OK/);
      if(testCommandCancel) {
        await page.waitForFunction(()=>events.some(event=>event.type==='log' && /STUDIO_COMMAND_CANCEL_OK|STUDIO_CANCEL_ASSERTION/.test(event.message)),null,{timeout:10000});
        report.cancellationFailure=await page.evaluate(()=>events.find(event=>event.type==='log' && event.message.includes('STUDIO_CANCEL_ASSERTION'))?.message);
        assert.equal(report.cancellationFailure,undefined);
        report.originalCommandCancellationVerified=true;
        await page.waitForFunction(()=>events.some(event=>event.type==='log' && /STUDIO_COMMAND_TIMEOUT_RECOVERED|STUDIO_TIMEOUT_ASSERTION/.test(event.message)),null,{timeout:10000});
        report.timeoutFailure=await page.evaluate(()=>events.find(event=>event.type==='log' && event.message.includes('STUDIO_TIMEOUT_ASSERTION'))?.message);
        assert.equal(report.timeoutFailure,undefined);
        report.originalCommandTimeoutRecoveryVerified=true;
        await page.waitForFunction(()=>events.some(event=>event.type==='log' && /STUDIO_COMMAND_OWNERSHIP_OK|STUDIO_OWNERSHIP_ASSERTION/.test(event.message)),null,{timeout:10000});
        report.ownershipFailure=await page.evaluate(()=>events.find(event=>event.type==='log' && event.message.includes('STUDIO_OWNERSHIP_ASSERTION'))?.message);
        assert.equal(report.ownershipFailure,undefined);
        report.originalCommandPreservesManualGame=true;
      }
    }
  }
  const firstFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
  if(testAgentTool) {
    assert.equal(await firstFrame.evaluate(()=>Module.FS.readFile('/game/agent-created.lua',{encoding:'utf8'})),agentCreatedSource);
    report.originalAgentEditedFile=true;
    if(testAgentPlay) {
      const captures=await firstFrame.evaluate(()=>Module.FS.readdir('/game/.agent/vision').filter(name=>/\.png$/.test(name)));
      assert.equal(captures.length,1);
      report.agentGeneratedPreviewFile=captures[0];
      const generated=await firstFrame.evaluate(name=>({
        source:Module.FS.readFile('/game/agent-created.lua',{encoding:'utf8'}),
        png:[...Module.FS.readFile('/game/.agent/vision/'+name)],name,
      }),captures[0]);
      const stored=await page.evaluate(async generated=>{
        const {LocalWorkspace,saveAgentFileChanges}=await import('/capture-storage.js');
        const database='agent-authoring-integration';
        let store=await LocalWorkspace.open(database);
        try {
          const original=await store.save('Author project',{version:1,projectId:'author',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print("author")'}]},null);
          const changes={projectId:'author',baseRevision:0,deletes:[],writes:[
            {path:'agent-created.lua',kind:'text',text:generated.source},
            {path:'.agent/vision/'+generated.name,kind:'binary',bytes:new Uint8Array(generated.png)},
          ]};
          await saveAgentFileChanges(store,original,changes,new AbortController().signal);
          store.close();store=await LocalWorkspace.open(database);
          const reopened=await store.load('author');
          let conflict=false;
          try {await saveAgentFileChanges(store,original,changes,new AbortController().signal);} catch(error) {if(error.code!=='conflict') throw error;conflict=true;}
          const after=await store.load('author');
          return {revision:after.snapshot.revision,source:reopened.snapshot.files.find(file=>file.path==='agent-created.lua').text,
            original:after.snapshot.files.find(file=>file.path==='init.lua').text,
            png:[...reopened.snapshot.files.find(file=>file.kind==='binary').bytes],
            checkpoints:await store.listCheckpoints('author'),conflict};
        } finally {store.close();}
      },generated);
      assert.equal(stored.revision,1);assert.equal(stored.source,agentCreatedSource);
      assert.equal(stored.original,'print("author")');assert.deepEqual(stored.png,generated.png);
      assert.deepEqual(stored.checkpoints,[0]);assert.equal(stored.conflict,true);
      report.agentOutputSavedToAuthorWorkspace=true;
    }
  }
  if(testCommandPreview || testAgentPlay) {
    const captures = await firstFrame.evaluate(()=>Module.FS.readdir('/game/.agent/vision')
      .filter(name=>/^\d+-\d+\.png$/.test(name))
      .map(name=>({name,bytes:[...Module.FS.readFile('/game/.agent/vision/'+name)]})));
    assert.equal(captures.length,testAgentPlay ? 1 : 2);
    report.originalPreviewPixels = [];
    for(const capture of captures) {
      const pixels = await page.evaluate(async ({bytes,name})=>{
        const bitmap = await createImageBitmap(new Blob([new Uint8Array(bytes)],{type:'image/png'}));
        try {
          const canvas = document.createElement('canvas');
          canvas.width=bitmap.width;canvas.height=bitmap.height;
          const context=canvas.getContext('2d');context.drawImage(bitmap,0,0);
          const {data}=context.getImageData(0,0,canvas.width,canvas.height);
          let green=0,red=0;
          for(let i=0;i<data.length;i+=4) {
            if(Math.abs(data[i]-76)<5 && Math.abs(data[i+1]-195)<5 && Math.abs(data[i+2]-138)<5) green++;
            if(data[i]>250 && data[i+1]<5 && data[i+2]<5) red++;
          }
          return {name,width:bitmap.width,height:bitmap.height,green,red};
        } finally {bitmap.close();}
      },capture);
      assert.equal(pixels.width,300);assert.equal(pixels.height,150);
      assert.ok(pixels.green>100,JSON.stringify(pixels));
      assert.equal(pixels.red,0,'Original preview must exclude host system UI');
      report.originalPreviewPixels.push(pixels);
    }
    report.originalPreviewPixelsVerified=true;
    if(testAgentPlay) report.agentGeneratedScenePixelsVerified=true;
  }
  assert.ok(firstFrame);
  if (testCapture || testCaptureRequest) {
    let returnedPNG;
    if (testCaptureRequest) {
      const result = await page.evaluate(async partial => {
        const {captureAgentRunBatch,LocalWorkspace}=await import('/capture-storage.js');
        let count=0;
        const run=partial ? {...initialRun,capture:async signal=>++count===1 ? initialRun.capture(signal) : {type:'captureFailed',message:'INJECTED_SECOND_FRAME_FAILURE'}} : initialRun;
        const saved=await captureAgentRunBatch(captureStore,captureProject,run,1,'capture-e2e',[0,0.1],new AbortController().signal);
        const result=saved.captures[0];
        captureStore.close();
        const reopened=await LocalWorkspace.open('runtime-capture-e2e');
        try {
          const project=await reopened.load('p');
          const restored=project.snapshot.files.find(file=>file.path===saved.files[0]);
          // Simulate later editing before replay: recovery must not roll it back.
          await reopened.save(project.name,{...project.snapshot,revision:3},2,true);
          const replayRun={...initialRun,capture(){throw new Error('REPLAY_MUST_NOT_CAPTURE');},stop(){throw new Error('REPLAY_MUST_NOT_STOP');}};
          const replay=await captureAgentRunBatch(reopened,captureProject,replayRun,1,'capture-e2e',[0,0.1],new AbortController().signal);
          let changedTimesRejected=false;
          try {await captureAgentRunBatch(reopened,captureProject,replayRun,1,'capture-e2e',[0,0.2],new AbortController().signal);}catch(error){changedTimesRejected=error.code==='conflict';}
          const afterReplay=await reopened.load('p');
          return {...result,png:[...result.png],storedPNG:[...restored.bytes],storedRevision:project.snapshot.revision,
            checkpoints:await reopened.listCheckpoints('p'),storedPath:saved.files[0],captureCount:saved.files.length,batchSuccess:saved.success,batchMessage:saved.message,
            replay:{changedTimesRejected,restored:replay.restored,historical:replay.historical,files:replay.files,success:replay.success,revision:replay.project.snapshot.revision,currentRevision:afterReplay.snapshot.revision},
            reservationReplay:await reopened.reserveVisionCapture('p',1,'capture-e2e',2)};
        } finally {reopened.close();}
      },testCapturePartial);
      assert.equal(result.type,'gameCaptured',result.message);
      returnedPNG=result.png;
      report.hostRequestedCaptureReturned=true;
      assert.deepEqual(result.storedPNG,result.png);
      assert.equal(result.storedRevision,2);assert.deepEqual(result.checkpoints,[2,1]);
      assert.equal(result.replay.restored,true);assert.equal(result.replay.historical,true);
      assert.equal(result.replay.changedTimesRejected,true);
      assert.equal(result.replay.revision,2);assert.equal(result.replay.currentRevision,3);
      assert.equal(result.replay.success,!testCapturePartial);assert.equal(result.replay.files[0],result.storedPath);
      report.completedCaptureReplayPreservesNewerRevision=true;
      assert.match(result.storedPath,/^\.agent\/vision\/\d+-\d+\.png$/);
      report.engineCapturePersistedAndReopened=true;
      assert.equal(result.reservationReplay.replayed,true);
      assert.equal(result.reservationReplay.budget.captureFrameCount,2);
      assert.equal(result.reservationReplay.result.revision,2);
      assert.equal(result.reservationReplay.result.success,!testCapturePartial);
      assert.equal(result.reservationReplay.result.files[0],result.storedPath);
      report.captureCompletionPersistedAtomically=true;
      assert.equal(result.captureCount,testCapturePartial ? 1 : 2);
      assert.equal(result.batchSuccess,!testCapturePartial);
      if(testCapturePartial) {assert.match(result.batchMessage,/INJECTED_SECOND_FRAME_FAILURE/);report.partialCapturePreserved=true;}
      report.captureReservationSurvivesReopen=true;
    } else await firstFrame.waitForFunction(() => Module.FS.analyzePath('/game/studio-capture.png').exists, null, {timeout:30000});
    const pixels = await firstFrame.evaluate(async pngInput => {
      const bytes = pngInput ? new Uint8Array(pngInput) : Module.FS.readFile('/game/studio-capture.png');
      const bitmap = await createImageBitmap(new Blob([bytes], {type:'image/png'}));
      const canvas = document.createElement('canvas');canvas.width=bitmap.width;canvas.height=bitmap.height;
      const context = canvas.getContext('2d');context.drawImage(bitmap,0,0);
      const data = context.getImageData(0,0,canvas.width,canvas.height).data;
      let green = 0, red = 0;
      for(let i=0;i<data.length;i+=4) {
        if(Math.abs(data[i]-76)<5 && Math.abs(data[i+1]-195)<5 && Math.abs(data[i+2]-138)<5) green++;
        if(data[i]>250 && data[i+1]<5 && data[i+2]<5) red++;
      }
      bitmap.close();
      return {width:canvas.width,height:canvas.height,green,red,bytes:bytes.length,png:[...bytes]};
    },returnedPNG);
    assert.ok(pixels.width > 0 && pixels.height > 0 && pixels.green > 100, JSON.stringify(pixels));
    assert.equal(pixels.red, 0, 'Existing system tool UI must not contaminate game captures');
    assert.equal(isBoundedCapturePNG(new Uint8Array(pixels.png),pixels.width,pixels.height),true);
    const {png, ...captureInfo} = pixels;
    report.engineGameCapture = captureInfo;
  }
  await firstFrame.evaluate(async () => {
    Module.FS.writeFile('/user/settings/studio-check.txt', 'project-p-save');
    await Module.doraSyncUserStorage();
  });
  await page.evaluate(() => host.stop());
  const deadline = Date.now() + 5000;
  while (page.workers().length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
  assert.equal(page.workers().length, 0);
  report.oldWorkersDestroyed = true;
  await page.evaluate(() => { window.previousRun = host.start(artifact); });
  await page.waitForFunction(() => events.filter(event => event.state === 'running').length === 2, null, { timeout: 55000 });
  report.events = await page.evaluate(() => events);
  assert.notEqual(report.events.filter(event => event.state === 'running')[1].runId, report.firstRun);
  const secondFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
  if(testAgentSession) {
    await page.waitForFunction(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_SESSION_TITLE')).length===2);
    const titles=await page.evaluate(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_SESSION_TITLE')).map(event=>event.message.split('STUDIO_AGENT_SESSION_TITLE')[1]));
    report.agentSessionTitles=titles;
    assert.equal(titles[1],titles[0],'Agent session must survive runtime restart');
    const childIds=await page.evaluate(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_CHILD_ID')).map(event=>Number(event.message.split('STUDIO_AGENT_CHILD_ID')[1])));
    assert.equal(childIds.length,2);
    assert.ok(childIds[1]>childIds[0],'Restart must retain existing child rows, not recreate an empty database');
    report.agentChildIds=childIds;
    report.agentSessionSurvivesRuntimeRestart=true;
    if(testAgentPrompt) {
      const replies=await page.evaluate(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_PREVIOUS_REPLIES')).map(event=>Number(event.message.split('STUDIO_AGENT_PREVIOUS_REPLIES')[1])));
      assert.equal(replies.length,2);
      assert.equal(replies[0],0);
      assert.ok(replies[1]>0,'Previously completed reply must be available before sending a new prompt');
      report.agentReplySurvivesRuntimeRestart=true;
    }
  }
  assert.equal(await secondFrame.evaluate(() => Module.FS.readFile('/user/settings/studio-check.txt', { encoding: 'utf8' })), 'project-p-save');
  await page.evaluate(() => { window.currentRun = host.start({ ...artifact, projectId: 'other-project' }); });
  await page.waitForFunction(() => events.filter(event => event.state === 'running').length === 3, null, { timeout: 55000 });
  const otherFrame = page.frames().find(frame => frame.url().startsWith(runtimeURL));
  if(testAgentSession) {
    await page.waitForFunction(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_CHILD_ID')).length===3);
    const ids=await page.evaluate(()=>events.filter(event=>event.type==='log' && event.message.includes('STUDIO_AGENT_CHILD_ID')).map(event=>Number(event.message.split('STUDIO_AGENT_CHILD_ID')[1])));
    assert.deepEqual(ids,[2,3,2],'Other project must start with its own database');
    report.agentDatabaseSeparatedByProject=true;
  }
  assert.equal(await otherFrame.evaluate(() => Module.FS.analyzePath('/user/settings/studio-check.txt').exists), false);
  report.storageRestoredAndSeparated = true;
  assert.equal(await page.evaluate(() => previousRun.stop()), false);
  assert.equal(await page.locator('iframe').count(), 1);
  assert.equal(await otherFrame.evaluate(() => Module.FS.analyzePath('/game').exists), true);
  assert.equal(await page.evaluate(() => currentRun.stop()), true);
  assert.equal(await page.evaluate(() => currentRun.stop()), false);
  assert.equal(await page.locator('iframe').count(), 0);
  report.runScopedCleanupProtectsNewPreview = true;
  assert.deepEqual(await page.evaluate(() => currentRun.ready), {state:'running',runId:await page.evaluate(()=>currentRun.runId)});
  const cancelledStartup = await page.evaluate(async () => {
    const run = host.start(artifact);
    run.stop();
    return await run.ready;
  });
  assert.equal(cancelledStartup.state, 'cancelled');
  const failedStartup = await page.evaluate(async () => {
    const run = host.start({...artifact,sha256:'0'.repeat(64)});
    return await run.ready;
  });
  assert.equal(failedStartup.state, 'failed');
  assert.equal(await page.locator('iframe').count(), 0);
  report.startupResultSettlesOnRunCancelAndFailure = true;
  if(!testCommandModule&&!testCapture&&!testCaptureRequest&&!testTeal){
    await page.evaluate(async()=>{
      const {mountPreview}=await import('/preview.js');const container=document.createElement('div');container.id='react-preview';document.body.append(container);
      window.componentPreview=mountPreview(container,window.artifact);
    });
    await page.getByText('正在运行',{exact:true}).waitFor({timeout:30000});
    assert.equal(await page.locator('#react-preview iframe').count(),1);
    await page.evaluate(()=>window.componentPreview.close());
    await page.waitForFunction(()=>!document.querySelector('#react-preview iframe'));
    report.realPreviewAutoRunAndUnmountPassed=true;
  }
  assert.equal(report.errors.length, 0);
  if(testAgentPrompt) assert.ok(!report.logs.some(log=>log.includes('onEvent handler failed')),'Agent event handler must not fail');
  report.passed = true;
  }
} catch (error) {
  report.failure = String(error);
  if(appPage){try{report.failureContext={alerts:await appPage.getByRole('alert').allTextContents(),projects:await appPage.getByRole('navigation',{name:'本机项目'}).getByRole('button').allTextContents(),confirmations:await appPage.locator('dialog.workspace-confirm').allTextContents()};}catch{/* Original failure remains authoritative. */}}
  process.exitCode = 1;
}
finally {
  await browser?.close();
  await appServer?.close();
  for (const server of [host, player]) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
  const output = `apps/web/artifacts/${testApp ? 'runtime-app' : 'runtime-host'}${suffix}`;
  await mkdir(output, { recursive: true });
  await writeFile(`${output}/result.json`, JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
}
