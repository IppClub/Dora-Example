// Independent WASM heaps, private metadata mirrors and rollback during active games.
import assert from 'node:assert/strict';import {pathToFileURL} from 'node:url';import path from 'node:path';
const root=process.env.DORA_ENGINE_ROOT||process.env.DORA_SSR_ROOT;if(!root)throw Error('Set DORA_ENGINE_ROOT');
const {GodotWebBridge}=await import(pathToFileURL(path.join(root,'Tools/Godot/web/runtime_bridge.js')));
function filesystem(){
 const nodes=new Map([['/',{mode:1}]]);
 const fs={nodes,isDir:mode=>mode===1,isLink:mode=>mode===2,analyzePath:p=>({exists:nodes.has(p)}),lookupPath:p=>{assert(nodes.has(p),p);return{node:nodes.get(p)};},
 readdir:p=>['.','..',...Array.from(nodes.keys()).filter(k=>k!=='/'&&k.slice(0,k.lastIndexOf('/'))===(p==='/'?'':p)).map(k=>k.slice(k.lastIndexOf('/')+1))],
 mkdir:p=>{assert(!nodes.has(p));nodes.set(p,{mode:1});},writeFile:(p,b)=>nodes.set(p,{mode:0,bytes:new Uint8Array(b)}),readFile:p=>nodes.get(p).bytes,
 unlink:p=>{assert(nodes.get(p).mode!==1);nodes.delete(p);},rmdir:p=>{assert.equal(fs.readdir(p).length,2);nodes.delete(p);}};return fs;
}
const source=filesystem(),target=filesystem(),text=new TextEncoder(),strings=new Map();let id=0;const freed=[],boundaries=[];
source.mkdir('/工程');source.writeFile('/工程/project.godot',text.encode('config_version=5'));
source.writeFile('/工程/main.tscn',text.encode('fresh scene'));source.writeFile('/工程/art.png',new Uint8Array(10000));source.nodes.set('/工程/escape',{mode:2});
target.mkdir('/tmp');target.mkdir('/工程');target.writeFile('/工程/main.tscn',text.encode('live old scene'));target.writeFile('/tmp/user-save',text.encode('keep'));
const snapshot=()=>JSON.stringify([...target.nodes].map(([key,value])=>[key,value.mode,value.bytes?[...value.bytes]:null]));const original=snapshot();
const g={FS:target,stringToNewUTF8:value=>{strings.set(++id,value);return id;},UTF8ToString:p=>strings.get(p),_free:p=>freed.push(p),
 _dora_web_inspect_scene:(p,f,o)=>{
  const project=strings.get(p),file=strings.get(f);assert(project.startsWith('/tmp/dora-scene-query-'));assert.equal(file,project+'/main.tscn');
  assert.deepEqual([...target.readFile(file)],[...text.encode('fresh scene')]);assert.equal(target.readFile(project+'/art.png').length,0);assert(!target.analyzePath(project+'/escape').exists);
  assert.equal(strings.get(o),'{}');return g.stringToNewUTF8(JSON.stringify({success:true,path:file,nodes:[],resources:[],connections:[]}));
 }};
const bridge=new GodotWebBridge({FS:source},g,{activate:v=>boundaries.push(v)});const copies=[{path:'/live'}];bridge.projectCopies=copies;
assert.equal(JSON.parse(bridge.inspectScene('/工程','/工程/main.tscn','{}')).path,'/工程/main.tscn');
assert.equal(snapshot(),original);assert.equal(bridge.projectCopies,copies);assert.equal(freed.length,3);assert.deepEqual(boundaries,['godot','host']);
g._dora_web_inspect_scene=()=>{throw Error('controlled native failure');};assert.throws(()=>bridge.inspectScene('/工程','/工程/main.tscn','{}'),/controlled/);assert.equal(snapshot(),original);
const write=target.writeFile;target.writeFile=(p,b)=>{write(p,b);throw Error('controlled partial write');};
assert.throws(()=>bridge.inspectScene('/工程','/工程/main.tscn','{}'),/partial write/);assert.equal(snapshot(),original);target.writeFile=write;
assert.throws(()=>bridge.inspectScene('/工程','/工程/../escape','{}'),/inside the project/);assert.equal(snapshot(),original);
delete g._dora_web_inspect_scene;assert.throws(()=>bridge.inspectScene('/工程','/工程/main.tscn','{}'),/no static scene inspection API/);
console.log('PASS: Web scene UTF-8/private metadata mirror, fresh saved source during active game, dependency markers, live-file preservation, capability/path guards and partial/native failure cleanup');
