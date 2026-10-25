import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import vm from 'node:vm';

const engine=process.env.DORA_ENGINE_ROOT;
const require=createRequire(path.join(engine,'Tools/dora-dora/package.json'));
const {build}=require('esbuild');
const {JSDOM}=createRequire(require.resolve('blockly'))('jsdom');
const dom=new JSDOM('<div id="root"></div>',{url:'http://localhost:8866'});
for(const name of ['window','document','HTMLElement'])globalThis[name]=dom.window[name];
globalThis.IS_REACT_ACT_ENVIRONMENT=true;
const React=require('react'),{createRoot}=require('react-dom/client');
const temp=mkdtempSync(path.join(tmpdir(),'dora-tic80-lifecycle-'));
const originalFetch=globalThis.fetch,originalError=console.error;
console.error=()=>{}; // Deliberate HTTP/empty-file failures are asserted below.
const fixture=globalThis.__ticFixture={path:path.posix};
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
const until=async check=>{for(let n=0;!check();n++){assert(n<200,'TIC-80 operation did not settle');await tick();}};
try {
 const output=path.join(temp,'editor.cjs');
 await build({entryPoints:[path.join(engine,'Tools/dora-dora/src/TIC80Editor.tsx')],outfile:output,bundle:true,platform:'node',format:'cjs',logLevel:'silent',plugins:[{name:'tic80-fixture',setup(builder){
  builder.onResolve({filter:/^react(?:\/.*)?$/},args=>({path:require.resolve(args.path),external:true}));
  builder.onResolve({filter:/^(react-i18next|\.\/Info|\.\/Service|\.\/Theme)$/},args=>({path:args.path,namespace:'fixture'}));
  builder.onLoad({filter:/.*/,namespace:'fixture'},args=>({loader:'js',contents:args.path==='./Info'?'export default {get path(){return globalThis.__ticFixture.path}}':args.path==='./Service'?'export const addr=p=>"http://localhost:8866"+p':args.path==='./Theme'?'export const Color={}':'export const useTranslation=()=>({t:(key,args)=>key+JSON.stringify(args||{})})'}));
 }}]});
 const Editor=require(output).default;
 for(const api of [path.posix,path.win32]) {
  fixture.path=api;
  const file=api===path.posix?'/workspace/游戏 & root/城 #1.tic':'C:\\workspace\\游戏 & root\\城 #1.tic';
  const replies=[],alerts=[],requests=[],pending=[];
  let saved=0,dirty=0;
  const root=createRoot(document.getElementById('root'));
  const props={title:file,filePath:file,resPath:'城 #1.tic',width:600,height:400,onKeydown(){},onDirty(){dirty++;},onSaved(){throw Error('stale callback');},addAlert:(...args)=>alerts.push(args)};
  await React.act(async()=>root.render(React.createElement(Editor,props)));
  const frame=document.querySelector('iframe'),win=frame.contentWindow;
  win.postMessage=(data,origin)=>replies.push({data,origin});
  await React.act(async()=>frame.dispatchEvent(new dom.window.Event('load')));
  await React.act(async()=>root.render(React.createElement(Editor,{...props,onSaved(){saved++;}})));
  const status=()=>document.querySelector('[role="status"]').textContent;
  assert(status().startsWith('tic.status.loading'));
  const send=(type,data={},origin=window.location.origin,source=win)=>window.dispatchEvent(new dom.window.MessageEvent('message',{data:{type,...data},origin,source}));
  globalThis.fetch=async(url,init)=>{requests.push({url,init});return new Response(new Uint8Array([1,2,3]));};
  send('TIC80_READ_FILE',{},'https://untrusted.invalid');
  send('TIC80_READ_FILE',{},window.location.origin,window);
  await tick();assert.equal(requests.length,0);
  await React.act(async()=>send('TIC80_LOADED'));assert(status().startsWith('tic.status.ready'));
  send('TIC80_READ_FILE',{requestId:7});await until(()=>replies.some(r=>r.data.requestId===7));
  assert.equal(requests[0].url,'http://localhost:8866/'+encodeURIComponent('城 #1.tic'));
  assert.equal(requests[0].init.cache,'no-store');
  assert.deepEqual([...replies.find(r=>r.data.requestId===7).data.rom],[1,2,3]);
  globalThis.fetch=async()=>new Response(new Uint8Array());
  send('TIC80_READ_FILE',{requestId:8});await until(()=>replies.some(r=>r.data.requestId===8));
  assert.equal(replies.find(r=>r.data.requestId===8).data.success,false);
  assert(alerts.some(a=>a[0].startsWith('tic.loadFailed')));
  await React.act(async()=>{});assert(status().startsWith('tic.status.loadFailed'));assert(document.querySelector('button'));
  await React.act(async()=>send('TIC80_LOADED'));
  await React.act(async()=>win.document.dispatchEvent(new win.KeyboardEvent('keydown',{key:'F1',bubbles:true})));assert(status().startsWith('tic.status.ready'));
  await React.act(async()=>win.document.dispatchEvent(new win.KeyboardEvent('keydown',{key:'a',bubbles:true})));assert(status().startsWith('tic.status.modified'));dirty=0;

  globalThis.fetch=(url,init)=>{requests.push({url,init});return new Promise(resolve=>pending.push(resolve));};
  const offset=requests.length;
  send('TIC80_WRITE_FILE',{requestId:10,rom:new Blob(['first'])});
  send('TIC80_WRITE_FILE',{requestId:11,rom:new Blob(['second'])});
  await until(()=>pending.length===1);await tick();assert.equal(requests.length,offset+1,'Saves must be serialized');await React.act(async()=>{});assert(status().startsWith('tic.status.saving'));
  const request=requests.at(-1),url=new URL(request.url);
  assert.equal(url.searchParams.get('path'),api.dirname(file));assert.equal(url.searchParams.get('name'),api.basename(file));
  assert.equal(request.init.body.get('file').name,api.basename(file));assert.equal(await request.init.body.get('file').text(),'first');
  win.document.dispatchEvent(new win.KeyboardEvent('keydown',{key:'a',bubbles:true}));assert.equal(dirty,1);
  pending[0](new Response(null,{status:200}));await until(()=>pending.length===2);
  assert.equal(saved,0,'An older save must not clear changes made while it was pending');
  pending[1](new Response(null,{status:507}));await until(()=>replies.some(r=>r.data.requestId===11));
  assert.equal(replies.find(r=>r.data.requestId===11).data.success,false);
  assert(alerts.some(a=>a[0].startsWith('tic.updateFailed')));await React.act(async()=>{});assert(status().startsWith('tic.status.saveFailed'));
  send('TIC80_WRITE_FILE',{requestId:12,rom:new Blob(['latest'])});await until(()=>pending.length===3);
  pending[2](new Response(null,{status:200}));await until(()=>saved===1);await React.act(async()=>{});assert(status().startsWith('tic.status.saved'));
  send('TIC80_WRITE_FILE',{requestId:13,rom:new Blob(['close while saving'])});await until(()=>pending.length===4);
  await React.act(async()=>root.unmount());pending[3](new Response(null,{status:200}));await until(()=>saved===2);
  send('TIC80_WRITE_FILE',{requestId:14,rom:new Blob(['after unmount'])});await tick();assert.equal(pending.length,4);
 }

 // Boot the actual bridge in both parent/runtime readiness orders.
 const html=readFileSync(path.join(engine,'Tools/dora-dora/public/tic80/index.html'),'utf8');
 const script=html.match(/<script type="text\/javascript">([\s\S]*?)<\/script>/)[1];
 for(const initFirst of [true,false]) {
  const sent=[],listeners={},dependencies=new Set(),timers=[],files=new Map();let fallback=0;
  const canvas={focus(){},addEventListener(){}};
  const parent={postMessage:(data,origin)=>sent.push({data,origin})};
  const context={Blob,Uint8Array,navigator:{userAgent:'test'},console:{error(){}},setTimeout(fn){timers.push(fn);},addRunDependency:name=>dependencies.add(name),removeRunDependency:name=>dependencies.delete(name),document:{getElementById:()=>canvas,addEventListener(){},createElement:()=>({}),getElementsByTagName:()=>[{parentNode:{insertBefore(){}}}]},parent,location:{origin:'http://localhost:8866'},addEventListener:(type,fn)=>{listeners[type]=fn;},FS:{close(){return 'closed';},mkdirTree(){},writeFile(p,data){files.set(p,data);context.FS.close({path:p,flags:1});},readFile(p){return files.get(p);}}};
  context.window=context;vm.createContext(context);vm.runInContext(script,context);
  context.Module.saveAs=()=>{fallback++;};
  const message=data=>listeners.message({source:parent,origin:context.location.origin,data});
  const init=()=>message({type:'TIC80_INIT',filePath:'C:\\游戏\\城 #1.tic'});
  if(initFirst)init();
  context.Module.preRun[0]();
  assert(dependencies.has('dora-cartridge'),'Runtime must wait for the project cartridge');
  if(!initFirst)init();
  assert.equal(sent.length,1);assert.equal(sent[0].data.type,'TIC80_READ_FILE');
  init();assert.equal(sent.length,1,'Repeated init must not import twice');
  message({type:'TIC80_READ_FILE_RESPONSE',success:true,rom:new Uint8Array([42,43])});await tick();
  assert.equal(dependencies.size,0);
  assert.deepEqual([...files.get('/dora-ide/cart.tic')],[42,43]);
  assert.equal(sent.length,1,'Preloading must not save the cartridge back');
  assert.deepEqual([...context.Module.arguments],['--skip','--fs=/dora-ide','--cmd=load cart.tic & edit']);
  context.FS.close({path:'/dora-ide/cart.tic',flags:0});timers.splice(0).forEach(fn=>fn());
  assert.equal(sent.at(-1).data.type,'TIC80_LOADED');
  context.FS.close({path:'/dora-ide/cart.tic',flags:0});assert.equal(timers.length,0);
  context.FS.close({path:'/virtual/config.lua',flags:1});assert.equal(sent.length,2);
  assert.equal(context.FS.close({path:'/dora-ide/cart.tic',flags:32833}),'closed');
  assert.equal(sent.length,3);assert.equal(sent.at(-1).data.type,'TIC80_WRITE_FILE');
  assert.deepEqual([...new Uint8Array(await sent.at(-1).data.rom.arrayBuffer())],[42,43]);
  assert(sent.every(item=>item.origin===context.location.origin));
  context.Module.saveAs(new Blob(['legacy get']),'cart.tic');assert.equal(sent.length,4);
  listeners.message({source:{},origin:context.location.origin,data:{type:'TIC80_INIT',filePath:'spoofed'}});assert.notEqual(context.tic80FilePath,'spoofed');
 }
 // A failed initial read must never start the default/empty cartridge.
 {
  const listeners={},dependencies=new Set();
  const context={navigator:{userAgent:'test'},document:{getElementById:()=>({focus(){},addEventListener(){}}),addEventListener(){},createElement:()=>({}),getElementsByTagName:()=>[{parentNode:{insertBefore(){}}}]},location:{origin:'http://localhost:8866'},parent:{postMessage(){}},addEventListener:(type,fn)=>{listeners[type]=fn;},addRunDependency:n=>dependencies.add(n),removeRunDependency:n=>dependencies.delete(n),FS:{close(){}},setTimeout(){}};
  context.window=context;vm.createContext(context);vm.runInContext(script,context);context.Module.saveAs=()=>{};
  context.Module.preRun[0]();listeners.message({source:context.parent,origin:context.location.origin,data:{type:'TIC80_INIT',filePath:'/failed.tic'}});
  listeners.message({source:context.parent,origin:context.location.origin,data:{type:'TIC80_READ_FILE_RESPONSE',success:false}});await tick();
  assert(dependencies.has('dora-cartridge'));
 }
 console.log('PASS: TIC-80 POSIX/Windows paths, fresh binary reads, empty/read errors, ordered saves, save failures, edits during save, tab close, automatic cartridge boot, readiness races, native Ctrl+S sync, persistent save status and failed-load blocking.');
} finally {
 globalThis.fetch=originalFetch;console.error=originalError;delete globalThis.__ticFixture;
 dom.window.close();rmSync(temp,{recursive:true,force:true});
}
